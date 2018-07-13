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

record AggregationBuffer {
  var instance;
  var pid = -1;

  proc init(type msgType, initialBufSize = 1024) {
    instance = new AggregationBufferImpl(msgType, initialBufSize);
    pid = instance.pid;
  }

  proc _value {
    if pid == -1 {
      halt("AggregationBuffer: Not initialized...");
    }

    return chpl_getPrivatizedCopy(instance.type, pid);
  }

  forwarding _value;
}

class FixedBufferPool : BufferPool {
  var fixedBufferSize : int(64);
  var recycleList : list(c_ptr(msgType));
  var lock$ : sync bool;

  proc init(type msgType, bufSize = 1024) {
    super.init(msgType);
    this.fixedBufferSize = bufSize;
  }

  proc getBuffer(desiredSize : int(64) = -1) : (c_ptr(msgType), int(64)) {
    var (ptr, len) = (c_nil : c_ptr(msgType), fixedBufferSize);
 
    // If requested a size that is not the norm, allocate a diposable buffer
    if desiredSize != -1 then return (c_malloc(msgType, desiredSize), desiredSize);

    lock$ = true;
    
    // Check recycle list...
    if recycleList.size == 0 {
      ptr = c_malloc(msgType, fixedBufferSize);
    } else {
      ptr = recycleList.pop_front();
    }

    lock$;
    return (ptr, len);
  }
  
  proc recycleBuffer(buf : c_ptr(msgType), len : int(64) = -1) {
    // If len is specified and if it is a length other than our fixed buffer sizes, just free it
    if len != -1 && len != fixedBufferSize {
      c_free(buf);
      return;
    }

    lock$ = true;
    recycleList.push_back(buf);
    lock$;
  }
}

class BufferPool {
  type msgType;
  
  proc init(type msgType) {
    this.msgType = msgType;
  }
  
  // Called to immediately find a new buffer to replace
  // the buffer about to be procesed. Returns new buffer
  // and the length.
  proc getBuffer(desiredSize : int(64) = -1) : (c_ptr(msgType), int(64)) {
    halt("'getBuffer' unimplemented...");
  }
  
  // Only called after buffer has been processed. Need to specify
  // the length of the buffer to recycle in the case that the
  // actual implementation is dynamic.
  proc recycleBuffer(buf : c_ptr(msgType), len : int(64) = -1) {
    halt("'recycleBuffer' unimplemented...");
  }
}

pragma "default intent is ref"
record Buffer {
  type msgType;
  var buf : c_ptr(msgType);
  var length : atomic int(64);
  var claimed : atomic int(64);
  var filled : atomic int(64);

  proc init(type msgType) {
    this.msgType = msgType;
  }
}

class AggregationBufferImpl {
  // Aggregated message to buffer
  type msgType;
  // Destination buffers, one per locale
  var destinationBuffers : [LocaleSpace] Buffer(msgType);
  // TODO: Parameterize this...
  var bufferPool : FixedBufferPool(msgType);
  var initialBufSize : int(64);

  // Privatization id
  var pid = -1;

  proc init(type msgType, initialBufSize = 1024) {
    this.msgType = msgType;
    
    complete();
    
    this.initialBufSize = initialBufSize;
    this.pid = _newPrivatizedClass(this);
    this.bufferPool = new FixedBufferPool(msgType, initialBufSize);
    forall buf in destinationBuffers {
      var (ptr, len) = bufferPool.getBuffer();
      buf.buf = ptr;
      buf.length.write(len);
    }
  }
  
  // TODO: 'fnArgs' may need to be privatized...
  proc init(other, pid : int) {
    this.msgType = other.msgType;

    complete();

    this.bufferPool = new FixedBufferPool(msgType, other.initialBufSize);
    forall buf in destinationBuffers {
      var (ptr, len) = bufferPool.getBuffer();
      buf.buf = ptr;
      buf.length.write(len);
    }
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
    
    var (ptr, sz) = aggregator.aggregate(locid, msg);
    if ptr != nil {
      begin {
        on Locales[locid] {
          var arr : [1..sz] msgType;
          bulk_get(c_ptrTo(arr), ptr.locale.id, ptr, sz);
          process(arr);
        }
        aggregator.processed(ptr, sz);
      }
    }
    
    The above will aggregate the 'msg' for the required locale, and if it is full, it will
    asynchronously handle processing the buffer, then pass the buffer and notify it has finished
    processing it.
  */
  proc aggregate(locid : int, msg : msgType) : (c_ptr(msgType), int(64)) {
    ref buffer = destinationBuffers[locid];

    // Claim an index
    var claim = buffer.claimed.fetchAdd(1);
    while claim >= buffer.length.peek() {
      while buffer.claimed.read() >= buffer.length.peek() {
        chpl_task_yield();
      }
      claim = buffer.claimed.fetchAdd(1);
    }

    // Claim and fill
    buffer.buf[claim] = msg;
    var nFilled = buffer.filled.fetchAdd(1) + 1;

    // Last to fill handles swapping buffer...
    if nFilled == buffer.length.peek() {
      var toProcess = buffer.buf;
      var toProcessLen = buffer.length.peek();
      var (newBuf, newLen) = bufferPool.getBuffer();

      // Update buffer (and consequently wake up waiters)
      buffer.buf = newBuf;
      buffer.length.write(newLen);
      buffer.filled.write(0);
      buffer.claimed.write(0);
      
      return (toProcess, toProcessLen);
    }

    return (c_nil : c_ptr(msgType), 0);
  }
  
  /*
    Recycles the buffer returned from 'aggregate'
  */
  proc processed(buf : c_ptr(msgType), len : int(64)) {
    bufferPool.recycleBuffer(buf, len);
  }
}

proc main() {
  const arrSize = 1024 * 1024 * 8;
  type msgType = (int, int);
  var arr : [1..arrSize] int;
  var aggregator = new AggregationBuffer(msgType);
  var timer : Timer;
  timer.start();
  on Locales[1] {
    var rng = makeRandomStream(int);
    const _arrSize = arrSize;
    forall i in 1..arrSize {
      var (ptr, sz) : (c_ptr(msgType), int(64)) = aggregator.aggregate(0, (rng.getNext(1, _arrSize), i));
      if ptr != nil {
        on Locales[0] {
          var tmp : [1..sz] msgType;
          bulk_get(c_ptrTo(tmp), ptr.locale.id, ptr, sz);
          forall (i,j) in tmp do arr[i] = j;
        }
        aggregator.processed(ptr, sz);
      }
    }
  }
  timer.stop();
  writeln("Aggregation Time: ", timer.elapsed());
  
  timer.clear();
  timer.start();
  on Locales[1] {
    var rng = makeRandomStream(int);
    const _arrSize = arrSize;
    forall i in 1..arrSize do arr[rng.getNext(1, _arrSize)] = i;
  }
  timer.stop();
  writeln("Naive Time: ", timer.elapsed());

  timer.clear();
  timer.start();
  var rng = makeRandomStream(int);
  forall i in 1..arrSize do arr[rng.getNext(1, arrSize)] = i;
  timer.stop();
  writeln("Best Case Time: ", timer.elapsed());
}
