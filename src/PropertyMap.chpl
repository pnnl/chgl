module PropertyMaps {
  use AggregationBuffer;
  use Utilities;
  
  /*
    Uninitialized property map (does not initialize nor privatize).
  */
  proc UninitializedPropertyMap(type propertyType) return new PropertyMap(propertyType, pid=-1, map=nil);

  /*
    Obtains the locale this object belongs to.
  */
  pragma "no doc"
  proc propertyToLocale(property) : locale {
    if numLocales == 1 then return Locales[0];
    return Locales[chpl__defaultHashWrapper(property) % numLocales];
  }

  pragma "always RVF"
    record PropertyMap {
      // Type of property.
      type propertyType;
      pragma "no doc"
      var map : unmanaged PropertyMapImpl(propertyType);
      pragma "no doc"
      var pid = -1;
      
      /*
        Create an empty property map.

        :arg propertyType: Type of properties.
      */
      proc init(type propertyType) {
        this.propertyType = propertyType;
        this.map = new unmanaged PropertyMapImpl(propertyType);
        this.pid = this.map.pid;
      }


      /*
        Create a shallow-copy of the property map. The resulting map refers to the same
        internals as the original.

        :arg other: Other property map.
      */
      proc init(other : PropertyMap(?propertyType)) {
        this.propertyType = propertyType;
        this.map = other.map;        
        this.pid = other.pid;
      }
      
      /*
        This initializer is used internally, as it is used to create an uninitialized version of this property map.
      */
      pragma "no doc"
      proc init(type propertyType, pid : int, map : unmanaged PropertyMapImpl(propertyType)) {
        this.propertyType = propertyType;
        this.map = map;        
        this.pid = pid;
      }
      
      /*
        Performs a deep-copy of a property map.

        :arg other: Other property map.
      */
      proc clone(other : PropertyMap(?propertyType)) {
        this.propertyType = propertyType;
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

  pragma "no doc"
  class PropertyMapping {
    type propertyType;
    var lock$ : sync bool;
    var dom : domain(propertyType);
    var arr : [dom] int;

    proc init(type propertyType) {
      this.propertyType = propertyType;
    }

    proc init(other : PropertyMapping(?propertyType)) {
      this.propertyType = propertyType;
      other.lock$.writeEF(true);
      this.dom = other.dom;
      this.arr = other.arr;
      other.lock$.readFE();
    }

    proc append(other : this.type) {
      other.lock$.writeEF(true);
      this.dom += other.dom;
      other.lock$.readFE();
    }

    proc addProperty(property : propertyType) {
      lock$ = true;
      dom += property;
      arr[property] = -1;
      lock$;
    }

    proc setProperty(property : propertyType, id : int) {
      lock$ = true;
      dom += property;
      arr[property] = id;
      lock$;
    } 

    proc getProperty(property : propertyType) : int {
      lock$ = true;
      assert(dom.contains(property), property, " was not found in: ", dom); 
      var retval = arr[property];
      lock$;
      return retval;
    }

    proc numProperties() : int {
      lock$ = true;
      var retval = dom.size;
      lock$;
      return retval;
    }

    iter these() : (propertyType, int) {
      for (prop, ix) in zip(dom, arr) do yield (prop, ix);
    }

    iter these(param tag : iterKind) : (propertyType, int) where tag == iterKind.standalone {
      forall (prop, ix) in zip(dom, arr) do yield (prop, ix);
    }
  }
  
  class PropertyMapImpl {
    type propertyType;
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

    proc init(type propertyType) {
      this.propertyType = propertyType;
      this.pid = _newPrivatizedClass(this:unmanaged);
    }

    proc init(other : PropertyMapImpl(?propertyType)) {
      this.propertyType = propertyType;
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
      return (pid, aggregator);
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

    proc setProperty(property : propertyType, id : int, param aggregated = false, param acquireLock = true) {
      const loc = propertyToLocale(property);
      
      if aggregated {
        var buf = aggregator.aggregate((property, id), loc);
        if buf != nil {
          begin on loc {
            var arr = buf.getArray();
            buf.done();
            var _this = getPrivatizedInstance();
            local {
              if acquireLock then _this.lock.acquire();
              for (prop, id) in arr {
                _this.keys += prop;
                _this.values[prop] = id;
              }
              if acquireLock then _this.lock.release();
            }
          }
        }
      } else {
        on loc {
          var _this = getPrivatizedInstance();
          if acquireLock then _this.lock.acquire();          
          _this.keys += property;
          _this.values[property] = id;
          if acquireLock then _this.lock.release();
        }
      }
    }

    proc getProperty(property : propertyType, param acquireLock) : int {
      const loc = propertyToLocale(property);
      
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
    iter properties() : (propertyType, int) {
      for (k,v) in zip(keys, values) do yield (k,v);
    }
  
    /*
      Obtains global property keys and values (parallel).
    */
    iter properties(param tag : iterKind) : (propertyType, int) where tag == iterKind.standalone {
      coforall loc in Locales do on loc {
        var _this = getPrivatizedThis();
        forall (k,v) in zip(_this.keys, _this.values) do yield (k,v);
      }
    }
  }
}
