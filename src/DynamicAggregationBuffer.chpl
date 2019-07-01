/*
  Dynamic aggregator that will hold all buffers to be sent until explicitly requested
  by the user. This avoids the need to have to handle sending partial data when it is
  not needed to make progress. This comes with the issue that if no explicit flush is
  called, data never gets sent, but it opens the possibility of the user creating
  their own background progress task.
*/
module DynamicAggregationBuffer {
  use AggregationBuffer;

  proc UninitializedDynamicAggregator(type msgType) return new DynamicAggregator(msgType, instance=nil, pid=-1);
  
  pragma "always RVF"
  record DynamicAggregator {
    type msgType;
    var pid = -1;
    var instance : unmanaged DynamicAggregatorImpl(msgType);

    proc init(type msgType) {
      this.msgType = msgType;
      var instance = new unmanaged DynamicAggregatorImpl(msgType);
      this.pid = instance.pid;
      this.instance = instance;
    }

    proc init(type msgType, instance : unmanaged DynamicAggregatorImpl(msgType), pid : int) {
      this.msgType = msgType;
      this.pid = pid;
      this.instance = instance;
    }

    proc init(other) {
      this.msgType = other.msgType;
      this.pid = other.pid;
      this.instance = other.instance;
    }

    proc destroy() {
      if pid == -1 || instance == nil then halt("Attempt to destroy DynamicAggregator not initialized...");
      coforall loc in Locales do on loc {
        delete chpl_getPrivatizedCopy(instance.type, pid):unmanaged;
      }
      this.instance = nil;
    }
    
    proc isInitialized() {
      return pid != -1;
    }
    
    proc _value {
      if pid == -1 {
        halt("Aggregator: Not initialized...");
      }

      return chpl_getPrivatizedCopy(instance.type, pid);
    }

    forwarding _value;
  }

  class DynamicBuffer {
    type msgType;
    var dom = {0..-1};
    var arr : [dom] msgType;
    var lock : atomic bool;

    inline proc acquire() {
      if !lock.testAndSet() {
        return;
      }
      while lock.read() == true || lock.testAndSet() == true {
        chpl_task_yield();
      }
    }

    inline proc release() {
      lock.clear();
    }

    proc append(buf) {
      acquire();
      arr.push_back(buf);
      release();
    }

    proc getArray() {
      const _dom = dom;
      var _arr : [_dom] msgType = arr;
      return _arr;
    }

    proc done() {
      this.dom = {0..-1};
    }

    proc size return arr.size;
  }

  class DynamicAggregatorImpl {
    type msgType;
    var pid : int;
    var agg = UninitializedAggregator(msgType);
    var dynamicDestBuffers : [LocaleSpace] owned DynamicBuffer(msgType);

    proc init(type msgType) {
      this.msgType = msgType;
      this.agg = new Aggregator(msgType);
      complete();

      this.pid = _newPrivatizedClass(_to_unmanaged(this));
      forall buf in dynamicDestBuffers { 
        buf = new owned DynamicBuffer(msgType);
      }
    }

    proc init(other, pid : int) {
      this.msgType = other.msgType;
      this.pid = pid;
      this.agg = other.agg;
      complete();

      forall buf in dynamicDestBuffers { 
        buf = new owned DynamicBuffer(msgType);
      }
    }
    
    proc dsiPrivatize(pid) {
      return new unmanaged DynamicAggregatorImpl(this, pid);
    }

    proc dsiGetPrivatizeData() {
      return pid;
    }

    inline proc getPrivatizedInstance() {
      return chpl_getPrivatizedCopy(this.type, pid);
    }

    proc aggregate(msg : msgType, loc : locale) : void {
      aggregate(msg, loc.id);
    }
    
    proc aggregate(msg : msgType, locid : int) : void {
      var buf = agg.aggregate(msg, locid);
      if buf != nil {
        dynamicDestBuffers[locid].append(buf.getArray());
        buf.done();
      }
    }

    iter flushLocal() : (DynamicBuffer(msgType), locale) {
     for (buf, loc) in agg.flushLocal() {
        dynamicDestBuffers[loc.id].append(buf.getArray());
        buf.done();
      }
      // Give dynamic buffers to users
      for (buf, loc) in zip(dynamicDestBuffers, dynamicDestBuffers.domain) {
        if buf.size != 0 then yield (buf, Locales[loc]);
      }
    }

    iter flushLocal(param tag : iterKind) where tag == iterKind.standalone {
     forall (buf, loc) in agg.flushLocal() {
        dynamicDestBuffers[loc.id].append(buf.getArray());
        buf.done();
      }
      // Give dynamic buffers to users
      forall (buf, loc) in zip(dynamicDestBuffers, dynamicDestBuffers.domain) {
        if buf.size != 0 then yield (buf, Locales[loc]);
      }
    }

    iter flushGlobal() : (DynamicBuffer(msgType), locale) {
      halt("Serial 'flush' not implemented, use 'forall'...");
    }
     
    iter flushGlobal(param tag : iterKind) : (DynamicBuffer(msgType), locale) where tag == iterKind.standalone {
      // Flush aggregator first...
      forall (buf, loc) in agg.flushGlobal() {
        getPrivatizedInstance().dynamicDestBuffers[loc.id].append(buf.getArray());
        buf.done();
      }
      // Give dynamic buffers to users
      coforall loc in Locales do on loc {
        var _this = getPrivatizedInstance();
        forall (buf, loc) in zip (_this.dynamicDestBuffers, _this.dynamicDestBuffers.domain) {
          if buf.size != 0 then yield (buf, Locales[loc]);
        }
      }
    }
  }
}
