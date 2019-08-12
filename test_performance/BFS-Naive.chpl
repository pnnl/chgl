use CyclicDist;
use ReplicatedDist;
use Time;
use Sort;

config const dataset = "../data/karate.mtx_csr.bin";
config const numEdgesPresent = true;
config const doWorkStealing = true;
config const printTiming = false;
config const arrayGrowthRate = 1.5;
config const debugBFS = false;
config const isOptimized = false;

pragma "default intent is ref"
record Array {
  type eltType;
  var dom = {0..0};
  var arr : [dom] eltType;
  var sz : int;
  var cap : int = 1;

  proc preallocate(length : int) {
    if cap < length {
      this.cap = length;
      this.dom = {0..#this.cap};
    }
  }

  iter these() {
    if sz != 0 {
      if this.locale != here {
        var _dom = {0..#sz};
        var _arr : [_dom] eltType = arr;
        for a in arr[0..#sz] do yield a;
      } else {
        for a in arr[0..#sz] do yield a;
      }
    }
  }

  iter these(param tag : iterKind) where tag == iterKind.standalone {
    if sz != 0 then
      if this.locale != here {
        var _dom = {0..#sz};
        var _arr : [_dom] eltType = arr;
        forall a in arr[0..#sz] do yield a;
      } else {
        forall a in arr[0..#sz] do yield a;
      }
  }
  
  proc append(ref other : this.type) {
    const otherSz = other.sz;
    if otherSz == 0 then return;
    local { 
      if sz + otherSz > cap {
        this.cap = sz + otherSz;
        this.dom = {0..#cap};
      }
    }
    this.arr[sz..#otherSz] = other.arr[0..#otherSz];
    sz += otherSz;
  }

  proc append(elt : int) {
    local {
      if sz == cap {
        var oldCap = cap;
        cap = round(cap * arrayGrowthRate) : int;
        if oldCap == cap then cap += 1;
        this.dom = {0..#cap};
      }
    
      this.arr[sz] = elt;
      sz += 1;
    }
  }

  inline proc this(idx) return arr[idx];

  pragma "no copy return"
  proc getArray() {
    return arr[0..#sz];
  }

  proc clear() {
    local do this.sz = 0;
  }

  proc size return sz;
}


class CommunicationBuffer {
  var buf : c_ptr(int);
  var sz : int;
  var cap : int;

  proc write(otherBuf : c_ptr(int), otherSz : int) {
    if otherSz == 0 then return;
    if this.buf == nil {
      this.buf = c_malloc(int, otherSz);
      this.sz = otherSz;
      this.cap = otherSz;
    } else if otherSz > this.cap {
      c_free(buf);
      this.buf = c_malloc(int, otherSz);
      this.sz = otherSz;
      this.cap = otherSz;
    }
    
    c_memcpy(this.buf, otherBuf, otherSz * 8);
    this.sz = otherSz;
  }
}

pragma "no doc"
pragma "default intent is ref"
record Lock {
  var _lock : chpl__processorAtomicType(bool);

  inline proc acquire() {
    on this do local {
      if _lock.testAndSet() == true { 
        while _lock.read() == true || _lock.testAndSet() == true {
          chpl_task_yield();
        }
      }
    }
  }

  inline proc release() {
    on this do local do _lock.clear();
  }
}

var numVertices : uint(64);
var numEdges : uint(64);

var globalTimer = new Timer();
var timer = new Timer();
globalTimer.start();
timer.start();

// TODO: Perform two phases: First phase reads all offsets into task-local array,
// next one reads from those offsets with a single reader (monotonically increasing order of offsets)
try! {
  var f = open(dataset, iomode.r, style = new iostyle(binary=1));   
  var reader = f.reader();
  
  // Read in |V| and |E|
  
  reader.read(numVertices);
  if debugBFS then writeln("|V| = " + numVertices);
  if numEdgesPresent {
    reader.read(numEdges);
    if debugBFS then writeln("|E| = " + numEdges);
  }
  reader.close();
  f.close();
}

var D = {0..#numVertices} dmapped Cyclic(startIdx=0);
var A : [D] Array(int);

try! {
  // On each node, independently process the file and offsets...
  coforall loc in Locales do on loc {
    var f = open(dataset, iomode.r, style = new iostyle(binary=1));    
    // Obtain offset for indices that are local to each node...
    var dom = D.localSubdomain();
    coforall chunk in chunks(dom.low..dom.high by dom.stride align dom.alignment, here.maxTaskPar) {
      var reader = f.reader(locking=false);
      for idx in chunk {
        reader.mark();
        // Open file again and skip to portion of file we want...
        const headerOffset = if numEdgesPresent then 16 else 8;
        reader.advance(headerOffset + idx * 8);

        // Read our beginning and ending offset... since the ending is the next
        // offset minus one, we can just read it from the file and avoid
        // unnecessary communication with other nodes.
        var beginOffset : uint(64);
        var endOffset : uint(64);
        reader.read(beginOffset);
        reader.read(endOffset);
        endOffset -= 1;

        // Advance to current idx's offset...
        var skip = ((numVertices - idx:uint - 1:uint) + beginOffset) * 8;
        reader.advance(skip:int);

        // Pre-allocate buffer for vector and read directly into it
        A[idx].dom = {0..#(endOffset - beginOffset + 1)};
        reader.readBytes(c_ptrTo(A[idx].arr), ((endOffset - beginOffset + 1) * 8) : ssize_t);
        A[idx].sz = A[idx].dom.size;
        A[idx].cap = A[idx].dom.size;
        sort(A[idx].arr);
        reader.revert();
      }
    }
    f.close();
  }
}

timer.stop();
if printTiming then writeln("Initialization: ", timer.elapsed());
timer.clear();

// Use aggregation to send via active message then fetch via GET
if !isOptimized {
  // Replicate two work queues on each locale.
  var globalWorkDom = {0..1} dmapped Replicated();
  var globalLocks : [globalWorkDom] Lock;
  var globalWork : [globalWorkDom] Array(int);
  // Index of our current work queue
  var globalWorkIdx : int;
  // Push root vertex on queue.
  on A[0] do globalWork[globalWorkIdx].append(0);
  // Keep track of which vertices we have already visited.
  var visited : [D] atomic bool;
  var numPhases = 1;
  var lastTime : real;
  timer.start();
  while true {
    if debugBFS {
      var globalSize : int;
      coforall loc in Locales with (+ reduce globalSize) do on loc {
        globalSize += globalWork[globalWorkIdx].size;
      }
      writeln("Level #", numPhases, " has ", globalSize, " elements...");
    }
    // Spawn one task per locale; then consume all work from the work queue in parallel.
    coforall loc in Locales do on loc {
      // Aggregate outgoing work...
      var localeLock : [LocaleSpace] Lock;
      var localeWork : [LocaleSpace] Array(int);
      ref workQueue = globalWork[globalWorkIdx];

      // Coalesce duplicates if not using RDMA atomics; uses parallel radix sort (O(N))
      // then uses a simple insertion sort that just moves non-duplicates up.
      if workQueue.size != 0 {
        local {
          sort(workQueue.arr[0..#workQueue.size]);
          var lastValue = workQueue.arr[0];
          var leftIdx = 1;
          var rightIdx = 1;
          while rightIdx < workQueue.size {
            if workQueue.arr[rightIdx] != lastValue {
              lastValue = workQueue.arr[rightIdx];
              workQueue.arr[leftIdx] = lastValue;
              leftIdx += 1;
            }
            rightIdx += 1;
          }
          workQueue.sz = leftIdx;
        }
      }
      // Chunk up the work queue such that each task gets its own chunk
      coforall chunk in chunks(0..#workQueue.size, numChunks=here.maxTaskPar) {
        // Aggregate outgoing work...
        var localWork : [LocaleSpace] Array(int);
        for idx in chunk {
          const vertex = workQueue[idx];
          // Check if current vertex has been visited.
          if visited[vertex].testAndSet() == false {
            for neighbor in A[vertex] {
              localWork[neighbor % numLocales].append(neighbor);
            }
          }
        }
        // Perform a local reduction first.
        for (lock, _localeWork, _localWork) in zip(localeLock, localeWork, localWork) {
          local {
            lock.acquire();
            _localeWork.append(_localWork);
            lock.release();
          }
        }
      }

      // Perform a global, all-to-all reduction.
      coforall loc in Locales do on loc {
        globalLocks[globalWorkIdx].acquire();
        globalWork[(globalWorkIdx + 1) % 2].append(localeWork[here.id]);
        globalLocks[globalWorkIdx].release();
      }
      globalWork[globalWorkIdx].clear();
    }
    globalWorkIdx = (globalWorkIdx + 1) % 2;
    var currTime = timer.elapsed();
    if debugBFS then writeln("Finished phase #", numPhases, " in ", currTime - lastTime, "s");
    lastTime = currTime;
    numPhases += 1;

    var globalSize = + reduce globalWork.replicand(Locales)[globalWorkIdx].size;
    if globalSize == 0 then break;
  }
} else {
  // Use aggregation via pre-allocated communication buffer to fetch purely via GET, no active message
  // globalCommMatrix[i,j]: CommunicationBuffer from i to j; i -> j
  var globalCommMatrix : [0..#numLocales, 0..#numLocales] unmanaged CommunicationBuffer;
  forall (i,j) in globalCommMatrix.domain do on Locales[i] {
    globalCommMatrix[i,j] = new unmanaged CommunicationBuffer();
  }
  // Replicate a work queue on each locale.
  var globalWorkDom = {0..0} dmapped Replicated();
  var globalWork : [globalWorkDom] Array(int);
  // Push root vertex on queue.
  on A[0] do globalWork[0].append(0);
  // Keep track of which vertices we have already visited.
  var visited : [D] atomic bool;
  var numPhases = 1;
  var lastTime : real;
  timer.start();
  while true {
    var globalSize : int;

    // Spawn one task per locale; then consume all work from the work queue in parallel.
    coforall loc in Locales with (+ reduce globalSize) do on loc {
      var localCommMatrix : [0..#numLocales, 0..#numLocales] unmanaged CommunicationBuffer = globalCommMatrix;
      var localeLock : [LocaleSpace] Lock;
      var localeWork : [LocaleSpace] Array(int);
      ref workQueue = globalWork[0];

      // Fetch pending data from other locales.
      var sz = + reduce localCommMatrix[0..#numLocales, here.id].sz;
      if sz != 0 {
        workQueue.preallocate(sz);
        var offset : atomic int;
        forall buf in localCommMatrix[0..#numLocales, here.id] {
          var sz = buf.sz;
          if sz != 0 {
            var ourOffset = offset.fetchAdd(sz);
            __primitive("chpl_comm_array_get", c_ptrTo(workQueue.arr[ourOffset])[0], buf.locale.id, buf.buf[0], sz);
          }
        }
        workQueue.sz = sz;
      }

      // Coalesce duplicates if not using RDMA atomics; uses parallel radix sort (O(N))
      // then uses a simple insertion sort that just moves non-duplicates up.
      if workQueue.size != 0 {
        local {
          sort(workQueue.arr[0..#workQueue.size]);
          var lastValue = workQueue.arr[0];
          var leftIdx = 1;
          var rightIdx = 1;
          while rightIdx < workQueue.size {
            if workQueue.arr[rightIdx] != lastValue {
              lastValue = workQueue.arr[rightIdx];
              workQueue.arr[leftIdx] = lastValue;
              leftIdx += 1;
            }
            rightIdx += 1;
          }
          workQueue.sz = leftIdx;
        }
      }
      // Chunk up the work queue such that each task gets its own chunk
      coforall chunk in chunks(0..#workQueue.size, numChunks=here.maxTaskPar) {
        // Aggregate outgoing work...
        var localWork : [LocaleSpace] Array(int);
        for idx in chunk {
          const vertex = workQueue[idx];
          // Check if current vertex has been visited.
          if visited[vertex].testAndSet() == false {
            for neighbor in A[vertex] {
              localWork[neighbor % numLocales].append(neighbor);
            }
          }
        }
        // Perform a local reduction first.
        for (lock, _localeWork, _localWork) in zip(localeLock, localeWork, localWork) {
          local {
            lock.acquire();
            _localeWork.append(_localWork);
            lock.release();
          }
        }
      }

      // Prepare data to be sent.
      forall locidx in LocaleSpace with (+ reduce globalSize) {
        globalSize += localeWork[locidx].size;
        localCommMatrix[here.id, locidx].write(c_ptrTo(localeWork[locidx].arr[0]), localeWork[locidx].size);
      }
      workQueue.clear();
    }

    if globalSize == 0 then break;
    if debugBFS then writeln("Level #", numPhases + 1, " has ", globalSize, " elements...");
    var currTime = timer.elapsed();
    if debugBFS then writeln("Finished phase #", numPhases, " in ", currTime - lastTime, "s");
    lastTime = currTime;
    numPhases += 1;
  }
}

timer.stop();
globalTimer.stop();
if debugBFS then writeln("|V| = ", numVertices, ", |E| = ", numEdges);
if printTiming then writeln("BFS: ", timer.elapsed());
if printTiming then writeln("Total: ", globalTimer.elapsed());