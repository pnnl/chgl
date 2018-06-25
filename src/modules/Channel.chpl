module Channel {

  enum SlaveStatus {
    WAITING, BUSY
  };
  
  // The metadata contains information that the master and slave use to 
  // communicate with each other, done via low-level message-passing via c_ptrs.
  // First 8 bytes contains the size of the payload that follows after.
  // When the slave is serving a request, it will read the first 8 bytes,
  // then the rest of the payload; when it is finished it will notify the
  // master via its 'isDone' field (that is local to the master). When the
  // master receives sees that it 'isDone', it will then read the payload
  // and process accordingly. When the master wants to send a request, it
  // will write to the slave.
  record SlaveMeta {
    var slave : SlaveChannel;
    // Allocated on the slave... when this is resized, the slave needs
    // to update the master's pipe to point to the new 'pipe'.
    var pipe : c_void_ptr;
    // Updated remotely by the slave, checked locally by master
    var status : SlaveStatus = WAITING;
  }
  
  class Channel {
    var other : Channel;
    var outBuf : c_void_ptr;
    var outBufSize : c_size_t;
    var inBuf : c_void_ptr;
    var inBufPending : atomic bool;
  }
  
  proc Channel.init() {
    this.outBuf = c_malloc(c_sizeof(c_size_t));
    this.outBufSize = c_sizeof(c_size_t);
  }

  proc Channel.pair(other : Channel) {
    this.other = other;
    this.inBuf = other.outBuf;
    other.inBuf = this.outBuf;
  }
  
  proc Channel.send(data : c_ptr(?sendType)) {
    if this.other != nil {
      // Check size of current buffer
      if this.outBufSize < c_sizeof(sendType) + c_sizeof(c_size_t) {
        c_free(this.outBuf);
        this.outBuf = c_malloc(c_uint8_t, c_sizeof(sendType) + c_sizeof(c_size_t));
        other.inBuf = this.outBuf;
      }

      // Write locally...
      (this.outBuf : c_ptr(c_size_t))[0] = c_sizeof(sendType);
      ((this.outBuf : c_ptr(c_uint8_t)) + c_sizeof(c_size_t)) : c_ptr(send
    }
  }
}
