
// Number of communication buffers to swap out as they are filled...
config param AdjListHyperGraphNumBuffers = 8;
// `c_sizeof` is not compile-time param function, need to calculate by hand
config param OperationDescriptorSize = 24;
// Size of buffer is enough for one megabyte of bulk transfer by default.
config param AdjListHyperGraphBufferSize = ((1024 * 1024) / OperationDescriptorSize) : int(64);

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

  proc getBuffer() : (c_ptr(msgType), int(64)) {
    var (ptr, len) = (c_nil, fixedBufferSize);
    lock$ = true;
    
    // Check recycle list...
    if recycleList.size == 0 {
      recycleList
    }

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
  proc getBuffer() : (c_ptr(msgType), int(64)) {
    halt("'getBuffer' unimplemented...");
  }
  
  // Only called after buffer has been processed. Need to specify
  // the length of the buffer to recycle in the case that the
  // actual implementation is dynamic.
  proc recycleBuffer(buf : c_ptr(msgType), len : int(64)) {
    halt("'recycleBuffer' unimplemented...");
  }
}

class AggregationBufferImpl {
  // Aggregated message to buffer
  type msgType;
  // Aggregation handler
  var fnArgs;
  var fn;
  // Destination buffers, one per locale
  var destinationBuffers : [LocaleSpace] c_ptr(msgType); 
  var bufferPool : BufferPool(msgType);

  // Privatization id
  var pid = -1;

  proc init(type msgType, fnArgs, fn) {
    this.msgType = msgType;
    this.fnArgs = fnArgs;
    this.fn = fn;

    complete();

    this.pid = _newPrivatizedClass(this);
  }
  
  // TODO: 'fnArgs' may need to be privatized...
  proc init(other, pid : int) {
    this.msgType = other.msgType;
    this.fnArgs = other.fnArgs;
    this.fn = other.fn;
  }
}



/*
   Status of the sendBuffer...
   */
// Buffer is okay to use and send...
param BUFFER_OK = 0;
// Buffer is full and is sending, cannot be used yet...
param BUFFER_SENDING = 1;
// Buffer is being sent, but not yet processed... can be used but not yet sent
param BUFFER_SENT = 2;


// Each locale will have its own communication buffer, which will handle
// sending and receiving data. TODO: Add documentation...
pragma "use default init"
pragma "default intent is ref"
record CommunicationBuffers {
  var locid : int(64);
  var sendBuffer :  AdjListHyperGraphNumBuffers * c_ptr(OperationDescriptor);
  var recvBuffer : AdjListHyperGraphNumBuffers * c_ptr(OperationDescriptor);

  // Status of send buffers...
  var bufferStatus : [1..AdjListHyperGraphNumBuffers] atomic int;
  // Index of currently processed buffer...
  var bufferIdx : atomic int;
  // Number of claimed slots of the buffer...
  var claimed : atomic int;
  // Number of filled claimed slots...
  var filled : atomic int;

  // Send data in bulk...
  proc send(idx) {
    const toSend = sendBuffer[idx];
    const toRecv = recvBuffer[idx];
    const sendSize = AdjListHyperGraphBufferSize;
    __primitive("chpl_comm_array_put", toSend[0], locid, toRecv[0], sendSize);
  }

  // Receive data in bulk...
  proc recv(idx) {
    const toSend = sendBuffer[idx];
    const toRecv = recvBuffer[idx];
    const recvSize = AdjListHyperGraphBufferSize;
    __primitive("chpl_comm_array_get", toRecv[0], locid, toSend[0], recvSize);
  }

  // Clear send buffer with default values
  proc zero(idx) {
    const toZero = sendBuffer[idx];
    const zeroSize = AdjListHyperGraphBufferSize * OperationDescriptorSize;
    c_memset(sendBuffer, 0, zeroSize);
  }

  // Appends operation descriptor to appropriate communication buffer. If buffer
  // is full, the task that was the last to fill the buffer will handle switching
  // out the current buffer and sending the full buffer. If the return value is
  // not 0, then it is index of the buffer that was sent but needs processing...
  proc append(op) : int {
    // Obtain our buffer slot; if we get an index out of bounds, we must wait
    // until the buffer has been swapped out by another thread...
    var idx = claimed.fetchAdd(1) + 1;
    while idx > AdjListHyperGraphBufferSize {
      chpl_task_yield();
      idx = claimed.fetchAdd(1) + 1;
    }
    assert(idx > 0);

    // We have a position in the buffer, now obtain the current buffer. The current
    // buffer will not be swapped out until we finish our operation, as we do not
    // notify that we have filled the buffer until after, which has a full memory
    // barrier. TODO: Relax the read of bufIdx?
    const bufIdx = bufferIdx.read();
    sendBuffer[bufIdx][idx] = op;
    const nFilled = filled.fetchAdd(1) + 1;

    // If we have filled the buffer, we are in charge of swapping them out...
    if nFilled == AdjListHyperGraphBufferSize {
      if AdjListHyperGraphNumBuffers <= 1 {
        halt("Logic unimplemented for AdjListHyperGraphNumBuffers == ", AdjListHyperGraphNumBuffers);
      }

      // If a pending operation has not finished, wait for it then claim it...
      while bufferStatus[bufIdx].read() != BUFFER_OK do chpl_task_yield();
      bufferStatus[bufIdx].write(BUFFER_SENDING);

      // Poll for a buffer not currently sending...
      var newBufIdx = bufIdx + 1;
      while true {
        if newBufIdx > AdjListHyperGraphNumBuffers {
          newBufIdx = 1;
          chpl_task_yield();
        }

        if newBufIdx != bufIdx && bufferStatus[newBufIdx].read() != BUFFER_SENDING {
          break;
        }
        newBufIdx += 1;
      }


      // Set as new buffer...
      bufferIdx.write(newBufIdx);
      filled.write(0);
      claimed.write(0);

      // Send buffer...
      send(bufIdx);
      bufferStatus[bufIdx].write(BUFFER_SENT);

      // Returns buffer needing to be processed on target locale...
      return bufIdx;
    }

    // Nothing needs to be done...
    return 0;
  }

  // Indicates that the buffer has been processed appropriate, freeing up its use.
  proc processed(idx) {
    bufferStatus[idx].write(BUFFER_OK);
  }
}
