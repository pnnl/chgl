/*
  TODO: Implement dynamic buffer pools where the buffers expand in size
*/

// Number of communication buffers to swap out as they are filled...
config param AdjListHyperGraphNumBuffers = 8;
// `c_sizeof` is not compile-time param function, need to calculate by hand
config param OperationDescriptorSize = 24;
// Size of buffer is enough for one megabyte of bulk transfer by default.
config param AdjListHyperGraphBufferSize = ((1024 * 1024) / OperationDescriptorSize) : int(64);


// Send data in bulk...
inline proc bulk_put(src : c_void_ptr, locid : integral, dest : c_void_ptr, size : integral) {
  __primitive("chpl_comm_array_put", src[0], locid, dest[0], size);
}

// Receive data in bulk...
inline proc bulk_get(dest : c_void_ptr, locid : integral, src : c_void_ptr, size : integral) {
  __primitive("chpl_comm_array_get", dest[0], locid, src[0], size);
}

record AggregationBuffer {
  var instance;
  var pid = -1;

  proc init(type msgType, numBuffers = 8, bufferSize = 1024) {
    instance = new AggregationBufferImpl(msgType, numBuffers, bufferSize);
    pid = instance.pid;
  }

  proc _value {
    if pid == -1 {
      halt("AggregationBuffer: Not initialized...");
    }

    return chpl_getPrivatizedClass(instance.type, pid);
  }

  forwarding _value;
}

class FixedBufferPool : BufferPool {
  var fixedBufferSize : int(64);
  var recycleList : list(c_ptr(msgType));
  var lock$ : sync bool;

  proc init(type msgType, bufSize = 1024) {
    super(msgType);
    this.fixedBufferSize = bufSize;
  }

  proc getBuffer(desiredSize : int(64) = -1) : (c_ptr(msgType), int(64)) {
    var (ptr, len) = (c_nil, fixedBufferSize);
 
    // If requested a size that is not the norm, allocate a diposable buffer
    if desiredSize != -1 then return c_malloc(msgType, desiredSize);

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

  proc init(type msgType, buf : c_ptr(msgType), length : int) {
    this.msgType = msgType;
    this.buf = buf;
    this.length.write(length);
  }
}

class AggregationBufferImpl {
  // Aggregated message to buffer
  type msgType;
  // Aggregation handler
  var fnArgs;
  var fn;
  // Destination buffers, one per locale
  var destinationBuffers : [LocaleSpace] Buffer(msgType);
  // TODO: Parameterize this...
  var bufferPool : FixedBufferPool(msgType);
  var initialBufSize : int(64);

  // Privatization id
  var pid = -1;

  proc init(type msgType, fnArgs, fn, initialBufSize = 1024) {
    this.msgType = msgType;
    this.fnArgs = fnArgs;
    this.fn = fn;
    
    complete();
    
    this.initialBufSize = initialBufSize;
    this.pid = _newPrivatizedClass(this);
    this.bufferPool = new FixedBufferPool(msgType, initialBufSize);
    forall buf in destinationBuffers {
      var (ptr, len) = bufferPool.getBuffer();
    }
  }
  
  // TODO: 'fnArgs' may need to be privatized...
  proc init(other, pid : int) {
    this.msgType = other.msgType;
    this.fnArgs = other.fnArgs;
    this.fn = other.fn;

    complete();

    this.bufferPool = new FixedBufferPool(msgType, other.initialBufSize);
    forall buf in destinationBuffers {
      var (ptr, len) = bufferPool.getBuffer();
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

  proc aggregate(locid : int, msg : msgType) {
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
      var toProcessLen = buffer.len;
      var (newBuf, newLen) = bufferPool.getBuffer();

      // Update buffer (and consequently wake up waiters)
      buffer.buf = newBuf;
      buffer.length.write(newLen);
      buffer.filled.write(0);
      buffer.claimed.write(0);

      begin {
        // Process buffer in new task
        on Locales[locid] {
          const _this = getPrivatizedInstance();
          var arr : [0..#toProcessLen] int;
          bulk_get(c_ptrTo(arr), buffer.locale.id, toProcess, toProcessLen);
          _this.fn(_this.args, arr);
        }

        // Recycle buffer...
        bufferPool.recycleBuffer(toProcess, toProcessLen);
      }
    }
  }
}
