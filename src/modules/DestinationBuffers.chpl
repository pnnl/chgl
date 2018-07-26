use Time;
use Random;

/*
  TODO List:
  1. Need to add a way to await all buffers being flushed... maybe have each bufferPool keep
     maintain a list of all buffers it has created, as well as a list of buffers that are free.
  2. Need to expand buffer size based on how often it is filled...
*/

config param AggregatorMaxBuffers = -1;
config param AggregatorBufferSize = 1024 * 1024;
config param AggregatorDebug = false;

proc debug(args...?nArgs) where AggregatorDebug {
  writeln(args);
}

proc debug(args...?nArgs) where !AggregatorDebug {
  // NOP
}


record Aggregator {
  var instance;
  var pid = -1;

  proc init(type msgType) {
    this.instance = new AggregatorImpl(msgType);
    this.pid = this.instance.pid;
  }

  proc init(other) {
    this.instance = other.instance;
    this.pid = other.pid;
  }

  proc destroy() {
    if pid == -1 || instance == nil then halt("Attempt to destroy Aggregator not initialized...");
    coforall loc in Locales do on loc {
      delete chpl_getPrivatizedCopy(instance.type, pid);
    }
    this.instance = nil;
  }

  proc _value {
    if pid == -1 {
      halt("Aggregator: Not initialized...");
    }

    return chpl_getPrivatizedCopy(instance.type, pid);
  }

  forwarding _value;
}

pragma "no doc"
class BufferPool {
  type msgType;
  var lock$ : sync bool;
  // Head of list of all buffers that can be recycled.
  var freeBufferList : Buffer(msgType);
  // Head of list of all allocated buffers.
  var allocatedBufferList : Buffer(msgType);
  // Number of buffers that are available to be recycled...
  var numFreeBuffers : atomic int;
  // Number of buffers that are currently allocated
  var numAllocatedBuffers : atomic int; 
  // Maximum number of allocated buffers
  const maxAllocatedBuffers : int;

  // Will allow enough for a single buffer per destination locale.
  proc init(type msgType, maxBufferSize = AggregatorMaxBuffers) {
    this.msgType = msgType;
    this.maxAllocatedBuffers = if maxBufferSize >= 0 then max(numLocales * 2, maxBufferSize) else -1;
  }

  proc deinit() {
    while allocatedBufferList != nil {
      var buf = allocatedBufferList;
      allocatedBufferList = buf._nextAllocatedBuffer;
      delete buf;
    }
  }

  inline proc canAllocateBuffer() {
    return maxAllocatedBuffers == -1 || numAllocatedBuffers.peek() < maxAllocatedBuffers;
  }

  proc getBuffer() : Buffer(msgType) {
    var buf : Buffer(msgType);
     
    while buf == nil {
      // Yield while we wait for a free buffer...
      while numFreeBuffers.peek() == 0 && !canAllocateBuffer() {
        debug(here, ": waiting on free buffer..., numAllocatedBuffers(", 
            numAllocatedBuffers.peek(), ") / maxAllocatedBuffers(", maxAllocatedBuffers, ")");
        chpl_task_yield();
      }

      lock$ = true;
      // Out of buffers, try to create a new one.
      // Note: Since we do this inside the lock we can relax all atomics
      if numFreeBuffers.peek() == 0 {
        if canAllocateBuffer() {
          buf = new Buffer(msgType);
          numAllocatedBuffers.add(1, memory_order_relaxed);
          buf._nextAllocatedBuffer = allocatedBufferList;
          allocatedBufferList = buf;
        }
      } else {
        numFreeBuffers.sub(1, memory_order_relaxed);
        buf = freeBufferList;
        freeBufferList = buf._nextFreeBuffer;
      }
      lock$;
    }
    
    buf._bufferPool = this;
    return buf;
  }
  
  proc recycleBuffer(buf : Buffer(msgType)) {
    assert(buf._stolen.peek() == false, "Buffer is considered stolen when attempting to recycle...", buf);
    lock$ = true;
    numFreeBuffers.add(1, memory_order_relaxed);
    buf._nextFreeBuffer = freeBufferList;
    freeBufferList = buf;
    lock$;
  }
  
  // Waits for all buffers to finish being processed, and prevents other
  // buffers from being recycled/used. A buffer is considered being 'processed'
  // when it is marked as 'stolen'. The buffer list can be scanned without the lock
  // as the buffer list is guaranteed to not delete any buffers until the buffer pool
  // is entirely deleted...
  proc awaitFinish() {
    var buf = allocatedBufferList;
    while buf != nil {
      buf._stolen.waitFor(false);
      buf = buf._nextAllocatedBuffer;
    }
  }
}

enum BufferStatus {
  // Succeeded in appending to buffer
  Success,
  // Failed in appending to buffer
  Failure,
  // Succeeded in appending to buffer; in charge of swapping
  SuccessSwap,
  // Failed in appending to buffer; in charge of swapping (UNUSED)
  FailureSwap
}

/*
  Buffer contains the aggregated data that the user aggregates. The buffer,
  if returned to the user, must be recycled back to the buffer pool by invoking
  'done'.
*/
class Buffer {
  // The type of the message
  type msgType;
  pragma "no doc"
  var _bufDom = {0..-1};
  pragma "no doc"
  var _buf : [_bufDom] msgType;
  var _claimed : atomic int;
  pragma "no doc"
  var _filled : atomic int;
  pragma "no doc"
  var _stolen : atomic bool;
  pragma "no doc"
  var _nextAllocatedBuffer : Buffer(msgType);
  pragma "no doc"
  var _nextFreeBuffer : Buffer(msgType);
  pragma "no doc"
  var _bufferPool : BufferPool(msgType);
  
  pragma "no doc"
  proc init(type msgType) {
    this.msgType = msgType;
    this._bufDom = {0..#AggregatorBufferSize};
  }
  
  pragma "no doc"
  proc readWriteThis(f) {
    f <~> new ioLiteral("{ msgType = ")
      <~> this.msgType : string
      <~> new ioLiteral(", domain = ")
      <~> this._bufDom
      <~> new ioLiteral(", claimed = ")
      <~> this._claimed.read()
      <~> new ioLiteral(", filled = ")
      <~> this._filled.read()
      <~> new ioLiteral(", stolen = ")
      <~> this._stolen.read()
      <~> new ioLiteral(" }");
  }
  
  /*
    Attempts to append 'msg' to the buffer. The algorithm uses a fetch-and-add
    (wait-free) counter for concurrent tasks to claim indices, and another fetch-and-add
    counter to keep track of how full the buffer is. If the indices obtained from the fetch-and-add
    are out of bounds, it returns BufferStatus.Failure indicating that the buffer has been filled up
    and is about to be flushed if not already, in which case the task should seek out a new buffer.
    If the buffer is not full and the task has successfully obtained an index, the task successfully
    appends it to the buffer. If the task is the last to fill the buffer, it returns BufferStatus.SuccessSwap
    indicating that the current task should be in charge of swapping out and processing this buffer.
    If the task is not the last to fill the buffer, it will just return BufferStatus.Success.
  */
  pragma "no doc"
  proc append(msg : msgType) : BufferStatus {
    // Claim an index
    var claim = _claimed.fetchAdd(1);
    if claim >= _bufDom.size then return BufferStatus.Failure;

    // Claim and fill
    _buf[claim] = msg;
    var nFilled = _filled.fetchAdd(1) + 1;
    assert(nFilled <= _bufDom.size, "nFilled(", nFilled, ") > ", _bufDom.size);

    // Last to fill handles swapping buffer...
    // Attempt to 'steal' the buffer for ourselves to handle flushing...
    // if some other thread has already stolen it, it means we don't need
    // to worry about doing any extra work...
    if nFilled == _bufDom.size && attemptSteal() { 
      return BufferStatus.SuccessSwap;
    }
    
    return BufferStatus.Success;
  }
  
  /*
    Attempts to steal this buffer for flushing.
  */
  pragma "no doc"
  inline proc attemptSteal() : bool {
    return !_stolen.testAndSet();
  }
  
  /* 
    Attempts to atomically claim the entire buffer; returns amount of buffer
    claimed. Note that you must wait for buffer to be filled first before attempting
    to flush, but by returning early we get to begin swapping the buffers while other
    tasks finish up their writes...
  */
  pragma "no doc"
  proc flush() : int {
    // Someone else stole buffer...
    if !attemptSteal() then return -1;
    
    // Exchange current buffer 
    return _claimed.exchange(_bufDom.size);
  }
  
  /*
    Resets all fields back to default state so that it can be used again.
  */
  pragma "no doc"
  proc reset() {
    this._stolen.write(false);
    this._filled.write(0);
    this._claimed.write(0);
  }
  
  /*
    Recycles self back to buffer pool. Using the buffer after invoking this
    method is subject to undefined behavior.
  */
  proc done() {
    on this {
      this.reset();
      this._bufferPool.recycleBuffer(this);
    }
  }
  
  /* 
    Wait for buffer to fill to a certain amount. This is useful when you
    wish to wait for all writes to a Buffer to finish so you can begin
    processing it.
  */
  pragma "no doc"
  proc waitFilled(n = _bufDom.size - 1) {
    _filled.waitFor(n);
  }
  
  /*
    Indexes into buffer. This will be remote if the buffer is.
  */
  inline proc this(idx : integral) {
    assert(idx < _filled.peek());
    return _buf[idx];
  }
  
  /*
   Iterates over buffer. The buffer is copied to current locale, so it will be local.
  */
  iter these() : msgType {
    if this.locale != here {
      var buf = _buf[0..#_filled.peek()];
      for msg in buf do yield msg;
    } else {
      for msg in _buf[0..#_filled.peek()] do yield msg;
    }
  }
  
  /*
    Iterates over buffer in parallel. The buffer is copied to current locale so it will be local.
  */
  iter these(param tag : iterKind) : msgType where tag == iterKind.standalone {
    if this.locale != here {
      var buf = _buf[0..#_filled.peek()];
      forall msg in buf do yield msg;
    } else {
      forall msg in _buf[0..#_filled.peek()] do yield msg;
    }
  }
  
  iter these(param tag : iterKind) : msgType where tag == iterKind.leader {
    if this.locale != here {
      var buf = _buf[0..#_filled.peek()];
      forall x in buf.these(tag) do yield (x, buf);
    } else {
      forall x in _buf[0..#_filled.peek()].these(tag) do yield (x, _buf);
    }
  }

  iter these(param tag : iterKind, followThis) : msgType where tag == iterKind.follower {
    var (x, buf) = followThis;
    forall msg in buf.these(tag, x) do yield msg;
  }

  inline proc getPtr() return c_ptrTo(_buf);
  inline proc getSize() return _filled.peek();
  inline proc getDomain() return {0.._filled.peek()};
  inline proc getArray() return _buf[0..#_filled.peek()];
}

class AggregatorImpl {
  type msgType;
  pragma "no doc"
  var destinationBuffers : [LocaleSpace] Buffer(msgType);
  pragma "no doc"
  var bufferPool: BufferPool(msgType);
  pragma "no doc"
  var pid = -1;

  proc init(type msgType) {
    this.msgType = msgType;
    
    complete();
    
    this.pid = _newPrivatizedClass(this);
    this.bufferPool = new BufferPool(msgType);
    forall buf in destinationBuffers do buf = bufferPool.getBuffer();
  }
  
  proc init(other, pid : int) {
    this.msgType = other.msgType;
    
    complete();
    
    this.bufferPool = new BufferPool(msgType);
    forall buf in destinationBuffers do buf = bufferPool.getBuffer();
  }

  proc deinit() {
    delete this.bufferPool;
  }
  
  proc dsiPrivatize(pid) {
    return new AggregatorImpl(this, pid);
  }

  proc dsiGetPrivatizeData() {
    return pid;
  }

  inline proc getPrivatizedInstance() {
    return chpl_getPrivatizedCopy(this.type, pid);
  }

  proc aggregate(msg : msgType, loc : locale) : Buffer(msgType) {
    return aggregate(msg, loc.id);
  }
  
  /*
    Buffers up data to the maximum size possible; will 'block' until space is available.
    Buffers are created on-the-fly by the buffer pool, so depending on the implementation,
    the 'down-time' is kept to an absolute minimum. If the task calling this function is the
    last to fill the buffer, they are chosen to handle emptying the buffer. Example usage
    would be...
    
    var buf = aggregator.aggregate(msg, loc);
    if buf != nil {
      begin {
        var ret = coalesce(buf);
        buf.done();
        on loc do process(ret);
      }
    }
    
    The above will aggregate the 'msg' for the target locale, and if it is full, it will
    asynchronously handle both coalescing the buffer locally and processing the coalesced
    data remotely. The buffer can be returned as soon as it has been coalesced, but it can
    also be used directly on the other locales; its up to the user to minimize 'down-time'
  */
  proc aggregate(msg : msgType, locid : int) : Buffer(msgType) {
    while true {
      var buf = destinationBuffers[locid];
      select buf.append(msg) {
        when BufferStatus.Success {
          return nil;
        }
        when BufferStatus.Failure {
          debug("Waiting on buffer ", buf, "  for locale ", here.id, " to locale ", locid);
          chpl_task_yield();
        }
        when BufferStatus.FailureSwap {
          halt("FailureSwap not implemented...");
        }
        when BufferStatus.SuccessSwap {
          debug("Swapping buffer for locale ", here.id, " to locale ", locid);
          var newBuf = bufferPool.getBuffer();
          assert(newBuf._stolen.peek() == false, "New buffer still set as stolen...", newBuf);
          destinationBuffers[locid] = newBuf;
          debug("Finished swapping buffer for locale", here.id, " to locale ", locid);
          return buf;
        }
      }
    }
    halt("Somehow broke out of while loop...");
  }
  
  iter flushGlobal(targetLocales = Locales) : (Buffer(msgType), locale) {
    halt("Serial 'flushGlobal' not implemented...");
  }

  iter flushGlobal(targetLocales = Locales, param tag : iterKind) : (Buffer(msgType), locale) where tag == iterKind.standalone {
    coforall loc in targetLocales do on loc {
      var _this = getPrivatizedInstance();
      forall buf in _this.flushLocal() do yield buf;
    }
  }
  
  iter flushLocal(targetLocales = Locales) : (Buffer(msgType), locale) {
    halt("Serial 'flushLocal' not implemented...");
  }

  iter flushLocal(targetLocales = Locales, param tag : iterKind) where tag == iterKind.standalone {
    forall loc in targetLocales {
      // Flush destination buffer for each locale
      var buf = destinationBuffers[loc.id];
      var numFlush = buf.flush();
      if numFlush > 0 {
        destinationBuffers[loc.id] = bufferPool.getBuffer();
        buf.waitFilled(numFlush);
        yield (buf, loc);
        buf.done();
      } else {
        // Clear the 'stolen' status
        buf.reset();
      }
    }
  }
}

use VisualDebug;
use Time;
use CyclicDist;
use BlockDist;
use Random;
use CommDiagnostics;
config const N=2000000 * here.maxTaskPar; // number of updates
config const M=1000 * here.maxTaskPar * numLocales; // size of table
proc main() {
  
   // allocate main table and array of random ints
  const Mspace = {0..M-1};
  const D = Mspace dmapped Cyclic(startIdx=Mspace.low);
  var A: [D] atomic int;

  const Nspace = {0..(N*numLocales - 1)};
  const D2 = Nspace dmapped Block(Nspace);
  var rindex: [D2] int;

  /* set up loop */
  fillRandom(rindex, 208); // the 208 is a seed
  forall r in rindex {
     r = mod(r, M);
  }

  var t: Timer;
  /*t.start();
  /* main loop */
  forall r in rindex {
      on A[r] do A[r].add(1); //atomic add
  }
  t.stop();
  writeln("Histogram (RA) Time: ", t.elapsed());

  t.clear();*/
  t.start();
  forall r in rindex {
    A[r].add(1);
  }
  t.stop();
  writeln("Histogram (NA) Time: ", t.elapsed());
  t.clear();
  
  inline proc handleBuffer(buf, loc) {
    var subdom = D.localSubdomain();
    on loc do subdom = D.localSubdomain();
    var counters : [subdom] int(64);
    for idx in buf do counters[idx] += 1;
    buf.done();
    on loc {
      var _tmp = counters;
      local do for (cnt, idx) in zip(_tmp, _tmp.domain) do if cnt > 0 then A[idx].add(cnt);
    }
  }
  var rloc : [rindex.domain] locale;
  forall (r, loc) in zip(rindex, rloc) do loc = r.locale;
  // TODO: File bug where not invoking 'new' but declaring as type results in type being 'nil'...
  var aggregator = new Aggregator(int);
  aggregator.create();
  t.start();
  sync forall (r, loc) in zip(rindex, rloc) with (in aggregator) {
    if loc == here {
      A[r].add(1);
    } else {
      var buf = aggregator.aggregate(loc.id, r);
      if buf != nil {
        begin handleBuffer(buf, loc);
      }
    }
  }
  forall (buf, loc) in aggregator.flushGlobal() {
    handleBuffer(buf, loc);
  }
  //stopVdebug();
  t.stop();
  writeln("Histogram-Aggregated Time: ", t.elapsed());
  aggregator.destroy();
  //stopVdebug();
  //stopVerboseComm();
}
