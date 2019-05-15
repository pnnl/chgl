
/*
  TODO: Experiment with expanding buffer sizes
*/
module AggregationBuffer {

  use Time;
  use Random;

  config const AggregatorMaxBuffers = -1;
  config const AggregatorBufferSize = 1024 * 1024;
  config param AggregatorDebug = false;

  proc debug(args...?nArgs) where AggregatorDebug {
    writeln(args);
  }

  proc debug(args...?nArgs) where !AggregatorDebug {
    // NOP
  }

  pragma "always RVF"
  record Aggregator {
    type msgType;
    var instance : unmanaged AggregatorImpl(msgType);
    var pid = -1;

    proc init(type msgType) {
      this.msgType = msgType;
      this.instance = new unmanaged AggregatorImpl(msgType);
      this.pid = this.instance.pid;
    }

    proc init(pid : int, instance) {
      this.msgType = instance.msgType;
      this.instance = instance;
      this.pid = pid;
    }

    proc init(other) {
      this.msgType = other.msgType;
      this.instance = other.instance;
      this.pid = other.pid;
    }

    proc destroy() {
      if pid == -1 || instance == nil then halt("Attempt to destroy Aggregator not initialized...");
      coforall loc in Locales do on loc {
        delete chpl_getPrivatizedCopy(instance.type, pid):unmanaged;
      }
      this.instance = nil;
    }

    proc _value {
      if pid == -1 {
        halt("Aggregator: Not initialized...");
      }

      return chpl_getPrivatizedCopy(instance.type, pid);
    }

    proc chpl__serialize() : (int, instance.type) {
      return (pid, nil : instance.type);
    }

    forwarding _value;
  }
  
  proc type Aggregator.chpl__deserialize((pid, instance)) {
    return new Aggregator(pid, instance);
  }

  pragma "no doc"
  class BufferPool {
    type msgType;
    var lock$ : sync bool;
    // Head of list of all buffers that can be recycled.
    var freeBufferList : unmanaged Buffer(msgType);
    // Head of list of all allocated buffers.
    var allocatedBufferList : unmanaged Buffer(msgType);
    // Number of buffers that are available to be recycled...
    var numFreeBuffers : chpl__processorAtomicType(int);
    // Number of buffers that are currently allocated
    var numAllocatedBuffers : chpl__processorAtomicType(int); 
    // Maximum number of allocated buffers
    const maxAllocatedBuffers : int;

    // Will allow enough for a single buffer per destination locale.
    proc init(type msgType, maxBufferSize = AggregatorMaxBuffers) {
      this.msgType = msgType;
      this.maxAllocatedBuffers = if maxBufferSize >= 0 then max(numLocales * 2, maxBufferSize) else -1;
    }

    proc deinit() {
      while allocatedBufferList != nil {
        var tmp = allocatedBufferList;
        allocatedBufferList = tmp._nextAllocatedBuffer;
        delete tmp;
      }
    }

    inline proc canAllocateBuffer() {
      return maxAllocatedBuffers == -1 || numAllocatedBuffers.peek() < maxAllocatedBuffers;
    }

    proc getBuffer() : unmanaged Buffer(msgType) {
      var buf : unmanaged Buffer(msgType);

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
            var tmp = new unmanaged Buffer(msgType);
            numAllocatedBuffers.add(1, memory_order_relaxed);
            tmp._nextAllocatedBuffer = allocatedBufferList;
            allocatedBufferList = tmp;
            buf = tmp;
          }
        } else {
          numFreeBuffers.sub(1, memory_order_relaxed);
          buf = freeBufferList;
          freeBufferList = buf._nextFreeBuffer;
        }
        lock$;
      }

      buf.reset();
      buf._bufferPool = _to_unmanaged(this);
      return buf;
    }

    proc recycleBuffer(buf : unmanaged Buffer(msgType)) {
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
    pragma "no doc"
    var _claimed : chpl__processorAtomicType(int);
    pragma "no doc"
    var _filled : chpl__processorAtomicType(int);
    pragma "no doc"
    var _stolen : chpl__processorAtomicType(bool);
    pragma "no doc"
    var _nextAllocatedBuffer : unmanaged Buffer(msgType);
    pragma "no doc"
    var _nextFreeBuffer : unmanaged Buffer(msgType);
    pragma "no doc"
    var _bufferPool : unmanaged BufferPool(msgType);

    pragma "no doc"
    proc init(type msgType) {
      this.msgType = msgType;
      this._bufDom = {0..#AggregatorBufferSize};
    }

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
      on this do this._bufferPool.recycleBuffer(_to_unmanaged(this));
    }

    /*
       Indexes into buffer. This will be remote if the buffer is.
    */
    inline proc this(idx : integral) ref {
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
    inline proc getDomain() return {0.._filled.peek()};
    inline proc getArray() return _buf[0..#_filled.peek()];
    inline proc size return _filled.peek();
    inline proc cap return _bufDom.size;
  }

  class AggregatorImpl {
    type msgType;
    pragma "no doc"
    var destinationBuffers : [LocaleSpace] unmanaged Buffer(msgType);
    pragma "no doc"
    var bufferPools : [LocaleSpace] unmanaged BufferPool(msgType);
    pragma "no doc"
    var pid = -1;

    proc init(type msgType) {
      this.msgType = msgType;

      complete();

      this.pid = _newPrivatizedClass(_to_unmanaged(this));
      forall (buf, pool) in zip (destinationBuffers, bufferPools) { 
        pool = new unmanaged BufferPool(msgType);
        buf = pool.getBuffer();
      }
    }

    proc init(other, pid : int) {
      this.msgType = other.msgType;

      complete();

      forall (buf, pool) in zip (destinationBuffers, bufferPools) { 
        pool = new unmanaged BufferPool(msgType);
        buf = pool.getBuffer();
      }
    }

    proc deinit() {
      delete this.bufferPools;
    }

    proc dsiPrivatize(pid) {
      return new unmanaged AggregatorImpl(this, pid);
    }

    proc dsiGetPrivatizeData() {
      return pid;
    }

    inline proc getPrivatizedInstance() {
      return chpl_getPrivatizedCopy(this.type, pid);
    }

    proc aggregate(msg : msgType, loc : locale) : unmanaged Buffer(msgType) {
      return aggregate(msg, loc.id);
    }
    
    proc aggregate(msg : msgType, locid : int) : unmanaged Buffer(msgType) {
      // Performs sanity checks to ensure that returned buffer is valid
      proc doSanityCheck(buf : unmanaged Buffer(msgType)) where AggregatorDebug {
        if buf._stolen.peek() != false then halt("Buffer is still stolen!", buf);
        if buf._claimed.peek() != 0 then halt("Buffer has not had claim reset...", buf);
        if buf._filled.peek() != 0 then halt("Buffer has not had filled reset...", buf);
      }
      proc doSanityCheck(buf : unmanaged Buffer(msgType)) where !AggregatorDebug {}
      
      while true {
        // Grab current buffer
        var buf = destinationBuffers[locid];

        // Claim an index
        var claim = buf._claimed.fetchAdd(1);
        
        // Could not claim a valid index, yield and try again
        if claim >= buf.cap {
          debug("Waiting on buffer ", buf, "  for locale ", here.id, " to locale ", locid);
          chpl_task_yield();
          continue;
        }

        // Claim and fill
        buf[claim] = msg;
        var nFilled = buf._filled.fetchAdd(1) + 1;
        assert(nFilled <= buf.cap, "nFilled(", nFilled, ") > ", buf.cap);

        // Last to fill handles swapping buffer...
        // Attempt to 'steal' the buffer for ourselves to handle flushing...
        // if some other thread has already stolen it, it means we don't need
        // to worry about doing any extra work...
        if nFilled == buf.cap && buf._stolen.testAndSet() == false { 
          debug("Swapping buffer for locale ", here.id, " to locale ", locid);
          var newBuf = bufferPools[locid].getBuffer();
          doSanityCheck(newBuf);
          destinationBuffers[locid] = newBuf;
          debug("Finished swapping buffer for locale", here.id, " to locale ", locid);
          return buf;
        }

        // No buffer to handle
        return nil;
      }
      halt("Somehow broke out of while loop...");
    }

    iter flushGlobal(targetLocales = Locales) : (unmanaged Buffer(msgType), locale) {
      halt("Serial 'flushGlobal' not implemented...");
    }

    iter flushGlobal(targetLocales = Locales, param tag : iterKind) : (unmanaged Buffer(msgType), locale) where tag == iterKind.standalone {
      const pid = this.pid;
      type thisType = this.type;
      coforall loc in targetLocales do on loc {
        var _this = chpl_getPrivatizedCopy(thisType, pid);
        forall buf in _this.flushLocal() do yield buf;
      }
    }

    iter flushLocal(targetLocales = Locales) : (unmanaged Buffer(msgType), locale) {
      halt("Serial 'flushLocal' not implemented...");
    }

    iter flushLocal(targetLocales = Locales, param tag : iterKind) : (unmanaged Buffer(msgType), locale) where tag == iterKind.standalone {
      forall loc in targetLocales {
        // Flush destination buffer for each locale
        var buf = destinationBuffers[loc.id];
        var stolen = buf._stolen.testAndSet() == false;
        
        // If we stole the buffer handle flushing it...
        // Note that if the buffer is being processed or
        // in the recycle list,we are unable to steal it.
        // Hence we only steal valid buffers.
        if stolen {
          // Simultaneously prevent new tasks from claiming indices
          // and obtain number of previously claimed indices.
          var claimed = buf._claimed.exchange(buf.cap);
          // Non-empty buffer
          if claimed > 0 {
            destinationBuffers[loc.id] = bufferPools[loc.id].getBuffer();
            // Wait for previous tasks that have claimed their
            // indices to finish.
            buf._filled.waitFor(claimed);
            yield (buf, loc);
          } else {
            // Clear the 'stolen' status;  the buffer does not get
            // swapped out so it is safe to do this.
            buf.reset();
          }
        }
      }
    }
  }
}
