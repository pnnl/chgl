module PropertyMaps {
  use AggregationBuffer;
  use HashedDist; // Hashed is not used, but the Mapper is
  use Utilities;
  use TerminationDetection;
  
  /*
    Uninitialized property map (does not initialize nor privatize).
  */
  proc UninitializedPropertyMap(type propertyType, mapper : ?t = new DefaultMapper()) return new PropertyMap(propertyType, mapper.type, pid=-1, nil);

  pragma "always RVF"
    record PropertyMap {
      // Type of property.
      type propertyType;
      // Type of mapper.
      type mapperType;
      pragma "no doc"
      var map : unmanaged PropertyMapImpl(propertyType, mapperType);
      pragma "no doc"
      var pid = -1;
      
      /*
        Create an empty property map.

        :arg propertyType: Type of properties.
        :arg mapper: Determines which locale to hash to.
      */
      proc init(type propertyType, mapper : ?mapperType = new DefaultMapper()) {
        this.propertyType = propertyType;
        this.mapperType = mapperType;
        this.map = new unmanaged PropertyMapImpl(propertyType, mapper);
        this.pid = this.map.pid;
      }


      /*
        Create a shallow-copy of the property map. The resulting map refers to the same
        internals as the original.

        :arg other: Other property map.
      */
      proc init(other : PropertyMap(?propertyType, ?mapperType)) {
        this.propertyType = propertyType;
        this.mapperType = mapperType;
        this.map = other.map;        
        this.pid = other.pid;
      }
      
      /*
        This initializer is used internally, as it is used to create an uninitialized version of this property map.
      */
      pragma "no doc"
      proc init(type propertyType, type mapperType, pid : int, map : unmanaged PropertyMapImpl(propertyType, mapperType)) {
        this.propertyType = propertyType;
        this.mapperType = mapperType;
        this.map = map;        
        this.pid = pid;
      }
      
      /*
        Performs a deep-copy of a property map.

        :arg other: Other property map.
      */
      proc clone(other : PropertyMap(?propertyType, ?mapperType)) {
        this.propertyType = propertyType;
        this.mapperType = mapperType;
        this.map = new unmanaged PropertyMap(other.map);
      }

      proc isInitialized return map != nil;

      proc _value {
        if boundsChecking && pid == -1 {
          halt("Attempt to use an uninitialized property map");
        }

        return chpl_getPrivatizedCopy(this.map.type, this.pid);
      }

      proc destroy() {
        if pid == -1 {
          halt("Atempt to use an uninitialized property map");
        }

        coforall loc in Locales do on loc {
          delete chpl_getPrivatizedCopy(this.map.type, this.pid);
        }
        this.pid = -1;
        this.map = nil;
      }

      forwarding _value;
    }

  class PropertyMapImpl {
    type propertyType;
    var mapper;
    var lock : Lock;
    // The properties
    pragma "no doc"
    var keys : domain(propertyType, parSafe=false);
    // The index they map to in the hypergraph or graph.
    pragma "no doc"
    var values : [keys] int;
    // Aggregation used to batch up potentially remote insertions.
    pragma "no doc"
    var setAggregator = UninitializedAggregator((propertyType, int));
    // Aggregation used to batch up potentially remote 'fetches' of properties.
    pragma "no doc"
    var getAggregator = UninitializedAggregator((propertyType, shared PropertyHandle));
    pragma "no doc"
    var terminationDetector : TerminationDetector;

    pragma "no doc"
    var pid = -1;

    proc init(type propertyType, mapper : ?t = new DefaultMapper()) {
      this.propertyType = propertyType;
      this.mapper = mapper;
      this.complete();
      this.setAggregator = new Aggregator((propertyType, int));
      this.getAggregator = new Aggregator((propertyType, shared PropertyHandle));
      this.terminationDetector = new TerminationDetector();
      this.pid = _newPrivatizedClass(this:unmanaged);
    }

    proc init(other : PropertyMapImpl(?propertyType)) {
      this.propertyType = propertyType;
      this.mapper = other.mapper;
      this.complete();
      this.setAggregator = new setAggregator((propertyType, int));
      this.terminationDetector = new TerminationDetector();

      this.pid = _newPrivatizedClass(this:unmanaged);
      const _pid = pid;
      coforall loc in Locales do on loc {
        var _this = chpl_getPrivatizedCopy(this.type, _pid);
        var _other = chpl_getPrivatizedCopy(other.type, _pid);
        _this.keys += _other.keys;
        _this.values = _other.values;
      }
    }

    pragma "no doc"
    proc init(other : PropertyMapImpl(?propertyType), privatizedData) {
      this.propertyType = propertyType;
      this.mapper = privatizedData[3];
      this.complete();
      this.pid = privatizedData[1];
      this.setAggregator = privatizedData[2];
      this.getAggregator = privatizedData[5];
      this.terminationDetector = privatizedData[4];
    }

    pragma "no doc"
    proc deinit() {
      // Only delete data from master locale
      if here == Locales[0] {
        setAggregator.destroy();
      }
    }

    pragma "no doc"
    proc dsiPrivatize(privatizedData) {
      return new unmanaged PropertyMapImpl(this, privatizedData);
    }

    pragma "no doc"
    proc dsiGetPrivatizeData() {
      return (pid, setAggregator, mapper, terminationDetector, getAggregator);
    }

    pragma "no doc"
    inline proc getPrivatizedInstance() {
      return chpl_getPrivatizedCopy(this.type, pid);
    }

    /*
      Appends the other property map's properties. If a property already exists, it will overwrite
      the current value if 'overwrite' policy is set.

      :arg other: Other property map to append.
      :arg overwrite: Whether or not to overwrite when a duplicate is found.
    */
    proc append(other : this.type, param overwrite = true, param acquireLock = true) {
      const _pid = pid;
      coforall loc in Locales do on loc {
        var _this = chpl_getPrivatizedCopy(this.type, _pid);
        var _other = chpl_getPrivatizedCopy(other.type, _pid);
        
        local {
          if acquireLock then acquireLocks(_this.lock, _other.lock);

          _this.keys += _other.keys;
          if overwrite { 
            _this.values = _other.values;
          } else {
            forall key in _other.keys {
              if !_this.keys.contains(key) {
                _this.values[key] = _other.values[key];
              }
            }
          }

          if acquireLock then releaseLocks(_this.lock, _other.lock);
        }
      }
    }

    proc create(property : propertyType, param aggregated = false, param acquireLock = true) {
      setProperty(property, -1, aggregated, acquireLock);
    }

    proc flushLocal(param acquireLock = true) {
      // Flush aggregation buffer 'setAggregator' first so any written
      // values are seen. Then flush 'getAggregator'.
      const _pid = pid;
      forall (buf, loc) in setAggregator.flushLocal() do on loc {
        var arr = buf.getArray();
        buf.done();
        var _this = chpl_getPrivatizedCopy(this.type, _pid);
        local {
          if acquireLock then _this.lock.acquire();
          for (prop, id) in arr {
            if id == -1 then _this.keys += prop;
            _this.values[prop] = id;
          }
          if acquireLock then _this.lock.release();
        }
      }

      forall (buf, loc) in getAggregator.flushLocal() {
        _flushGetAggregatorBuffer(buf, loc, acquireLock = acquireLock);
      }
    }
    proc flushGlobal(param acquireLock = true) {
      const _pid = pid;
      coforall loc in Locales do on loc {
        chpl_getPrivatizedCopy(this.type, _pid).flushLocal(acquireLock);
      }
      // Wait for any asynchronous tasks to finish
      terminationDetector.awaitTermination();
    }

    proc setProperty(property : propertyType, id : int, param aggregated = false, param acquireLock = true) {
      const loc = Locales[mapper(property, Locales)];
      const _pid = pid;
      
      if aggregated {
        var buf = setAggregator.aggregate((property, id), loc);
        if buf != nil {
          terminationDetector.started(1);
          begin on loc {
            var arr = buf.getArray();
            buf.done();
            var _this = chpl_getPrivatizedCopy(this.type, _pid);
            local {
              if acquireLock then _this.lock.acquire();
              for (prop, _id) in arr {
                if _id == -1 then _this.keys += prop;
                _this.values[prop] = _id;
              }
              if acquireLock then _this.lock.release();
              _this.terminationDetector.finished(1);
            }
          }
        }
      } else {
        on loc {
          var _this = chpl_getPrivatizedCopy(this.type, _pid);
          if acquireLock then _this.lock.acquire();          
          if id == -1 then _this.keys += property;
          _this.values[property] = id;
          if acquireLock then _this.lock.release();
        }
      }
    }

    proc _flushGetAggregatorBuffer(buf : Buffer, loc : locale, param acquireLock = true) {
      // Obtain separate array of properties and handles; we need to isolate properties
      // so we can do a bulk-transfer on the other locales.
      var arr = buf.getArray();
      buf.done();
      const arrSz = arr.size;
      var properties : [0..#arrSz] propertyType;
      var keys : [0..#arrSz] int;
      var handles : [0..#arrSz] shared PropertyHandle;
      forall ((prop, hndle), _prop, _hndle) in zip(arr, properties, handles) {
        _prop = prop;
        _hndle = hndle;
      }
      on loc {
        // Make local arrays to store directly into...
        var _this = getPrivatizedInstance();
        const localDomain = {0..#arrSz};
        // Remote bulk transfer (GET) x 2
        var _properties : [localDomain] propertyType = properties;
        var _keys : [localDomain] int;
        if acquireLock then _this.lock.acquire();

        // Gather all keys (local)
        forall (prop, key) in zip(_properties, _keys) {
          _keys = _this.values[prop];
        }
        if acquireLock then _this.lock.release();
        // Remote bulk transfer (PUT)
        keys = _keys; 
      }
      forall (key, handle) in zip(keys, handles) {
        handle.set(key);
      }
    }

    proc getPropertyAsync(property : propertyType, param acquireLock = true) : shared PropertyHandle {
      const loc = Locales[mapper(property, Locales)];

      var handle = new shared PropertyHandle();

      if loc == here {
        if acquireLock then this.lock.acquire();
        handle.set(this.values[property]);
        if acquireLock then this.lock.release();
      } else {
        var buf = getAggregator.aggregate((property, handle), loc);
        if buf != nil {
          terminationDetector.started(1);
          begin with (in buf, in loc) {
            _flushGetAggregatorBuffer(buf, loc, acquireLock);
            terminationDetector.finished(1);
          }
        }
      }

      return handle;
    }

    proc getProperty(property : propertyType, param acquireLock = true) : int {
      const loc = Locales[mapper(property, Locales)];
      
      var retid : int;
      const _pid = pid;
      on loc {
        var _this = chpl_getPrivatizedCopy(this.type, _pid);
        if acquireLock then _this.lock.acquire();
        retid = _this.values[property];
        if acquireLock then _this.lock.release();
      }
      return retid;
    }

    proc numProperties() : int {
      return keys.size;
    }

    proc numPropertiesGlobal() : int {
      var sz : int;
      const _pid = pid;
      coforall loc in Locales with (+ reduce sz) do on loc {
        var _this = chpl_getPrivatizedCopy(this.type, _pid);
        sz += _this.numProperties();
      }
      return sz;
    }
    
    /*
      Obtains local property keys and values (serial).
    */
    iter localProperties() : (propertyType, int) {
      for (k,v) in zip(keys, values) do yield (k,v);
    }

    iter localProperties() : (propertyType, int) {
      forall (k,v) in zip(keys, values) do yield (k,v);
    }
  
    iter these() : (propertyType, int) {
      halt("Serial 'these' not supported since serial iterators cannot yield from different locales;",
          "call 'localProperties' if you want properties for this node only!");
    }

    /*
      Obtains global property keys and values (parallel).
    */
    iter these(param tag : iterKind) : (propertyType, int) where tag == iterKind.standalone {
      const _pid = pid;
      coforall loc in Locales do on loc {
        var _this = chpl_getPrivatizedCopy(this.type, _pid);
        forall k in _this.keys { 
          if propertyType == string {
            yield (new string(k, isowned=false),_this.values[k]);
          } else {
            yield (k, _this.values[k]);
          }
        }
      }
    }
  }

  class PropertyHandle {
    var retVal : int;
    var ready : atomic bool;

    proc init() {}

    proc init(val : int) {
      this.retVal = val;
      this.read.write(true);
    }

    proc get() : int {
      ready.waitFor(true);
      return retVal;
    }

    proc set(val : int) {
      retVal = val;
      ready.write(true);
    }

    proc isReady() {
      return ready.read();
    }
  }

  // Side-steps issue where tuple assignment discards lifetime (including the wrapper somehow)
  // and results in a compiler error.
  proc =(ref x : (?t, _shared(PropertyHandle)), y : (t, _shared(PropertyHandle))) {
    x[1] = y[1];
    x[2] = y[2];
  }
}
