use RangeChunk;
use WorkQueue;
use BlockDist;
use Vectors;
use Utilities;
use Barriers;
use AllLocalesBarriers;
use DynamicAggregationBuffer;

config const dataset = "../data/karate.mtx_csr.bin";
config const numEdgesPresent = true;

try! {
  var time = new Timer();
  time.start();
  var f = open(dataset, iomode.r, style = new iostyle(binary=1));   
  var reader = f.reader();
  
  // Read in |V| and |E|
  var numVertices : uint(64);
  var numEdges : uint(64);
  reader.read(numVertices);
  debug("|V| = " + numVertices);
  if numEdgesPresent {
    reader.read(numEdges);
    debug("|E| = " + numEdges);
  }
  reader.close();
  f.close();
  
  
  var D = {0..#numVertices} dmapped Block(boundingBox={0..#numVertices});
  var A : [D] unmanaged Vector(int);
  
// On each node, independently process the file and offsets...
  coforall loc in Locales do on loc {
    var f = open(dataset, iomode.r, style = new iostyle(binary=1));    
    // Obtain offset for indices that are local to each node...
    var dom = D.localSubdomain();
    coforall chunk in chunks(dom.low..dom.high by dom.stride, here.maxTaskPar) {
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
        var vec = new unmanaged VectorImpl(int, {0..#(endOffset - beginOffset + 1)});
        reader.readBytes(c_ptrTo(vec.arr[0]), ((endOffset - beginOffset + 1) * 8) : ssize_t);
        vec.sz = (endOffset - beginOffset + 1) : int;
        vec.sort();
        A[idx] = vec;
        reader.revert();
      }
    }
  }
    
  time.stop();
  writeln("Initialization in ", time.elapsed(), "s");
  time.clear();
  
  allLocalesBarrier.reset(here.maxTaskPar);

  var current = new WorkQueue(int, WorkQueueUnlimitedAggregation);
  var next = new WorkQueue(int, WorkQueueUnlimitedAggregation);
  current.addWork(0, A[0].locale);
  current.flush();
  var visited : [D] atomic bool;
  if CHPL_NETWORK_ATOMICS != "none" then visited[0].write(true);
  var lastTime : real;
  time.start();
  var keepAlive : atomic bool;
  keepAlive.write(true);
  coforall loc in Locales do on loc {
    coforall tid in 0..#here.maxTaskPar {
      var numPhases = 0;
      var localCurrent = current;
      var localNext = next;
      while true {
        var (hasVertex, vertex) = localCurrent.getWork();
        if !hasVertex {
          allLocalesBarrier.barrier();
          if here.id == 0 && tid == 0 {
            localNext.flush();
            var elemsLeft = localNext.globalSize;
            writeln("Level #", numPhases, " has ", elemsLeft, " elements...");
            if elemsLeft == 0 then keepAlive.write(false);
          }
          allLocalesBarrier.barrier();
          if keepAlive.read() == false then break;
          numPhases += 1;
          localCurrent.pid <=> localNext.pid;
          localCurrent.instance <=> localNext.instance;
          continue;
        }

        // Set as visited here...
        if CHPL_NETWORK_ATOMICS != "none" || visited[vertex].testAndSet() == false {
          for neighbor in A[vertex] {
            if CHPL_NETWORK_ATOMICS != "none" && visited[neighbor].testAndSet() == true {
              continue;
            }
            localNext.addWork(neighbor, A[neighbor].locale);
          }
        } 
      }
    }
  }
  writeln("|V| = ", numVertices, ", |E| = ", numEdges, ", Completed BFS in ", time.elapsed(), "s");
  f.close();
}

