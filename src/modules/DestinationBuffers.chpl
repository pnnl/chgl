use Time;
use Random;

/*
  TODO: Implement dynamic buffer pools where the buffers expand in size
*/

// Send data in bulk...
inline proc bulk_put(src : c_ptr(?ptrType), locid : integral, dest : c_ptr(ptrType), size : integral) {
  __primitive("chpl_comm_array_put", src[0], locid, dest[0], size);
}

// Receive data in bulk...
inline proc bulk_get(dest : c_ptr(?ptrType), locid : integral, src : c_ptr(ptrType), size : integral) {
  __primitive("chpl_comm_array_get", dest[0], locid, src[0], size);
}


// TODO: Need to make this more configurable, but will do this once we need more than one type of buffer pool
config param AggregationBufferSize = 1024 * 1024;

record AggregationBuffer {
  var instance;
  var pid = -1;

  proc init(type msgType) {
    instance = new AggregationBufferImpl(msgType);
    pid = instance.pid;
  }

  proc _value {
    if pid == -1 || instance == nil {
      halt("AggregationBuffer: Not initialized...");
    }

    return chpl_getPrivatizedCopy(instance.type, pid);
  }

  forwarding _value;
}

class BufferPool {
  type msgType;
  var recycleList : list(Buffer(msgType));
  var lock$ : sync bool;

  proc init(type msgType) {
    this.msgType = msgType;
  }

  proc getBuffer(desiredSize : int(64) = -1) : Buffer(msgType) {
    var buf : Buffer(msgType);
    lock$ = true;
    
    // Check recycle list...
    if recycleList.size == 0 {
      buf = new Buffer(msgType);
    } else {
      buf = recycleList.pop_front();
    }

    lock$;
    return buf;
  }
  
  proc recycleBuffer(buf : Buffer(msgType)) {
    lock$ = true;
    recycleList.push_back(buf);
    lock$;
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

class Buffer {
  type msgType;
  var _bufDom = {0..-1};
  var _buf : [_bufDom] msgType;
  var _claimed : atomic int;
  var _filled : atomic int;
  var _stolen : atomic bool;

  proc init(type msgType) {
    this.msgType = msgType;
    this._bufDom = {0..#AggregationBufferSize};
  }
  
  // Not thread safe to copy...
  proc init(other : Buffer(?msgType)) {
    this.msgType = other.msgType;
    this._bufDom = other._bufDom;
    this._buf = other._buf;
    this.complete();
    this._claimed.write(other._claimed.read());
    this._filled.write(other._filled.write());
  }
  
  proc append(msg : msgType) : BufferStatus {
    // Claim an index
    var claim = _claimed.fetchAdd(1);
    if claim >= _bufDom.size then return BufferStatus.Failure;

    // Claim and fill
    _buf[claim] = msg;
    var nFilled = _filled.fetchAdd(1) + 1;
    
    // Last to fill handles swapping buffer...
    // Attempt to 'steal' the buffer for ourselves to handle flushing...
    // if some other thread has already stolen it, it means we don't need
    // to worry about doing any extra work...
    if nFilled == _bufDom.size && attemptSteal() { 
      return BufferStatus.SuccessSwap;
    }
    
    return BufferStatus.Success;
  }

  inline proc attemptSteal() : bool {
    return !_stolen.testAndSet();
  }
  
  // Attempts to atomically claim the entire buffer; returns amount of buffer
  // claimed. Note that you must wait for buffer to be filled first before attempting
  // to flush, but by returning early we get to begin swapping the buffers while other
  // tasks finish up their writes...
  proc flush() : int {
    // Someone else stole buffer...
    if !attemptSteal() then return -1;
    
    // Exchange current buffer 
    return _claimed.exchange(_bufDom.size);
  }

  proc reset() {
    this._filled.write(0);
    this._claimed.write(0);
  }
  
  // Wait for buffer to fill to a certain amount. This is useful when you
  // wish to wait for all writes to a Buffer to finish so you can begin
  // processing it. 
  proc waitFilled(n = _bufDom.size - 1) {
    _filled.waitFor(n);
  }

  inline proc this(idx : integral) {
    return _buf[idx];
  }

  iter these() : msgType {
    for msg in _buf do yield msg;
  }

  iter these(param tag : iterKind) : msgType where tag == iterKind.standalone {
    forall msg in _buf do yield msg;
  }

  iter these(param tag : iterKind) : msgType where tag == iterKind.leader {
    forall x in _buf.these(tag) do yield x;
  }

  iter these(param tag : iterKind, followThis) : msgType where tag == iterKind.follower {
    forall msg in _buf.these(tag, followThis) do yield msg;
  }

  // Exports buffer to 'c_ptr' for lower-level performance benefit
  inline proc getPtr() return c_ptrTo(_buf);
  inline proc getSize() return _bufDom.size;
  inline proc getDomain() return _bufDom;
  inline proc getArray(dom = _bufDom.low.._bufDom.high) return _buf[dom];
}

class AggregationBufferImpl {
  type msgType;
  var destinationBuffers : [LocaleSpace] Buffer(msgType);
  var bufferPool : BufferPool(msgType);
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
  
  proc dsiPrivatize(pid) {
    return new AggregationBufferImpl(this, pid);
  }

  proc dsiGetPrivatizeData() {
    return pid;
  }

  inline proc getPrivatizedInstance() {
    return chpl_getPrivatizedCopy(this.type, pid);
  }
  
  proc aggregate(loc : locale, msg : msgType) {
    aggregate(loc.id, msg);
  }
  
  /*
    Buffers up data to the maximum size possible; will 'block' until space is available.
    Buffers are created on-the-fly by the buffer pool, so depending on the implementation,
    the 'down-time' is kept to an absolute minimum. If the task calling this function is the
    last to fill the buffer, they are chosen to handle emptying the buffer. Example usage
    would be...
    
    var buffer = aggregator.aggregate(locid, msg);
    if buffer != nil {
      var arr = buffer.getArray();
      begin with (in arr) do on Locales[locid] {
        process(arr);
      }
      aggregator.processed(buffer);
    }
    
    The above will aggregate the 'msg' for the required locale, and if it is full, it will
    asynchronously handle processing the buffer, then pass the buffer and notify it has finished
    processing it.
  */
  proc aggregate(locid : int, msg : msgType) : Buffer(msgType) {
    while true {
      var buf = destinationBuffers[locid];
      select buf.append(msg) {
        when BufferStatus.Success {
          return nil;
        }
        when BufferStatus.Failure {
          chpl_task_yield();
        }
        when BufferStatus.FailureSwap {
          halt("FailureSwap not implemented...");
        }
        when BufferStatus.SuccessSwap {
          destinationBuffers[locid] = bufferPool.getBuffer();
          return buf;
        }
      }
    }
    halt("Somehow broke out of while loop...");
  }
  
  /*
    Recycles the buffer returned from 'aggregate'
  */
  proc processed(buf : Buffer(msgType)) {
    buf.reset();
    bufferPool.recycleBuffer(buf);
  }
  
  iter flushGlobal(targetLocales = Locales) {
    halt("Serial 'flushGlobal' not implemented...");
  }

  iter flushGlobal(targetLocales = Locales, param tag : iterKind) where tag == iterKind.standalone {
    coforall loc in targetLocales do on loc {
      var _this = getPrivatizedInstance();
      forall buf in _this.flushLocal() do yield buf;
    }
  }
  
  iter flushLocal(targetLocales = Locales) {
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
        on loc do yield buf.getArray(0..#numFlush);
        bufferPool.recycleBuffer(buf);
      }
    }
  }
}

use CommDiagnostics;
proc main() {
  const arrSize = 1024 * 1024 * 8;
  type msgType = (int, int);
  var arr : [1..arrSize] int;
  var aggregator = new AggregationBuffer(msgType);
  var timer : Timer;
  timer.start();
  on Locales[1] {
    var localAggregator = aggregator;
    var rng = makeRandomStream(int);
    const _arrSize = arrSize;
    forall i in 1.._arrSize {
      var buf = localAggregator.aggregate(0, (rng.getNext(1, _arrSize), i));
      if buf != nil {
        writeln("Have full buffer...");
        var tmp = buf.getArray();
        begin with (in tmp) on Locales[0] {
          forall (i,j) in tmp do arr[i] = j;
          localAggregator.processed(buf);
        }
      }
    }
  }
  forall buf in aggregator.flushGlobal() {
    forall (i, j) in buf do arr[i] = j;
  }
  timer.stop();
  writeln("Aggregation Time: ", timer.elapsed());
  
  timer.clear();
  timer.start();
  on Locales[1] {
    var rng = makeRandomStream(int);
    const _arrSize = arrSize;
    forall i in 1.._arrSize do arr[rng.getNext(1, _arrSize)] = i;
  }
  timer.stop();
  writeln("Naive AMO Time: ", timer.elapsed());
  
  timer.clear();
  timer.start();
  on Locales[1] {
    var rng = makeRandomStream(int);
    const _arrSize = arrSize;
    forall i in 1.._arrSize do on arr[rng.getNext(1, _arrSize)] {}
  }
  timer.stop();
  writeln("Naive Fast On Time: ", timer.elapsed());

  timer.clear();
  timer.start();
  var rng = makeRandomStream(int);
  forall i in 1..arrSize do arr[rng.getNext(1, arrSize)] = i;
  timer.stop();
  writeln("Best Case Time: ", timer.elapsed());
}
