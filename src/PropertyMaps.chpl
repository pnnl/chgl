module PropertyMaps {
  use AggregationBuffer;
  use HashedDist; // Hashed is not used, but the Mapper is
  use Utilities;
  
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
    var aggregator = UninitializedAggregator((propertyType, int)); 

    pragma "no doc"
    var pid = -1;

    proc init(type propertyType, mapper : ?t = new DefaultMapper()) {
      this.propertyType = propertyType;
      this.mapper = mapper;
      this.complete();
      this.aggregator = new Aggregator((propertyType, int));
      this.pid = _newPrivatizedClass(this:unmanaged);
    }

    proc init(other : PropertyMapImpl(?propertyType)) {
      this.propertyType = propertyType;
      this.mapper = other.mapper;
      this.aggregator = other.aggregator;
      this.complete();
      this.aggregator = new Aggregator((propertyType, int));
      
      this.pid = _newPrivatizedClass(this:unmanaged);
      coforall loc in Locales do on loc {
        var _this = getPrivatizedInstance();
        var _other = other.getPrivatizedInstance();
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
      this.aggregator = privatizedData[2];
    }

    pragma "no doc"
    proc deinit() {
      // Only delete data from master locale
      if here == Locales[0] {
        aggregator.destroy();
      }
    }

    pragma "no doc"
    proc dsiPrivatize(privatizedData) {
      return new unmanaged PropertyMapImpl(this, privatizedData);
    }

    pragma "no doc"
    proc dsiGetPrivatizeData() {
      return (pid, aggregator, mapper);
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
      coforall loc in Locales do on loc {
        var _this = getPrivatizedInstance();
        var _other = other.getPrivatizedInstance();
        
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
      coforall (buf, loc) in aggregator.flushLocal() do on loc {
        var arr = buf.getArray();
        buf.done();
        var _this = getPrivatizedInstance();
        local {
          if acquireLock then _this.lock.acquire();
          for (prop, id) in arr {
            if id == -1 then _this.keys += prop;
            _this.values[prop] = id;
          }
          if acquireLock then _this.lock.release();
        }
      }
    }
    proc flushGlobal(param acquireLock = true) {
      coforall loc in Locales do on loc {
        getPrivatizedInstance().flushLocal(acquireLock);
      }
    }

    proc setProperty(property : propertyType, id : int, param aggregated = false, param acquireLock = true) {
      const loc = Locales[mapper(property, Locales)];
      
      if aggregated {
        var buf = aggregator.aggregate((property, id), loc);
        if buf != nil {
          begin on loc {
            var arr = buf.getArray();
            buf.done();
            var _this = getPrivatizedInstance();
            local {
              if acquireLock then _this.lock.acquire();
              for (prop, _id) in arr {
                if _id == -1 then _this.keys += prop;
                _this.values[prop] = _id;
              }
              if acquireLock then _this.lock.release();
            }
          }
        }
      } else {
        on loc {
          var _this = getPrivatizedInstance();
          if acquireLock then _this.lock.acquire();          
          if id == -1 then _this.keys += property;
          _this.values[property] = id;
          if acquireLock then _this.lock.release();
        }
      }
    }

    proc getProperty(property : propertyType, param acquireLock = true) : int {
      const loc = Locales[mapper(property, Locales)];
      
      var retid : int;
      on loc {
        var _this = getPrivatizedInstance();
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
      coforall loc in Locales with (+ reduce sz) do on loc {
        var _this = getPrivatizedInstance();
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
      coforall loc in Locales do on loc {
        var _this = getPrivatizedInstance();
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
}
