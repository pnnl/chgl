/* This is the first data structure for hypergraphs in chgl.  This data
   structure is an adjacency list, where vertices and edges are in the "outer"
   distribution, and their adjacencies are in the "inner" distribution.
   Currently, the assumption is that the inner distribution of adjacencies is
   shared-memory, but it should be possible to easily change it to distributed.
   If we choose to distributed adjacency lists (neighbors), we may choose a
   threshold in the size of the adjacency list that causes the list of neighbors
   to be distributed since we do not want to distribute small neighbor lists.

   This version of the data structure started out in the SSCA2 benchmark and has
   been modified for the label propagation benchmark (both of these benchmarks
   are in the Chapel repository).  Borrowed from the chapel repository. Comes
   with Cray copyright and Apache license (see the Chapel repo).
 */
module AdjListHyperGraph {
  use IO;
  use CyclicDist;
  use List;
  use Sort;
  use Search;
  use AggregationBuffer;
  use Vectors;
  use PropertyMap;
  
  /*
    Disable aggregation. This will cause all calls to `addInclusionBuffered` to go to `addInclusion` and
    all calls to `flush` to do a NOP.
  */
  config const AdjListHyperGraphDisableAggregation = false;

  /*
    This will forward all calls to the original instance rather than the privatized instance.
  */
  config const AdjListHyperGraphDisablePrivatization = false;

  config param AdjListHyperGraphIndexBits = 64;

  /*
    Record-wrapper for the AdjListHyperGraphImpl. The record-wrapper follows from the optimization
    that Chapel's arrays, domains, and ranges use to eliminate communication that is inherent in
    in how Chapel represents pointers to potentially remote objects. Pointers in Chapel can be your
    normal 64-bit integer, or a widened 128-bit C struct, which holds both the 64-bit pointer
    as well as the locale id (32-bit integer) and a sublocale id (32-bit integer), the former used to
    describe the cluster node the memory is hosted on, and the latter describing the NUMA node the
    memory is allocated on. This is also the reason why you can declare a `atomic` class instance
    in Chapel.

    Since objects are hosted on a single node and do not migrate, a load and store to an object allocated
    in some other locale's address space will resolve to a GET and PUT respectively. Method invocation of
    a remote object is handled locally, but each load/store to the class fields are treated as remote PUT/GET,
    resulting in abysmal performance. To instruct that a method be performed on the locale that it is allocated
    on, care should be used that the body of the method is wrapped in an `on this` block. Note that it is not
    always appropriate to do this, as this creates a load imbalance and will result to degrading performance;
    as well, it has been found that with Cray's Aries Network Atomics, remote PUT/GET operations are significantly
    faster than remote execution. 

    The AdjListHyperGraph makes use of privatization, a process in which a local-copy of the object is created
    on each locale, documented as part of the DSI (Domain map Standard Interface). Privatization internally is
    implemented as a runtime table (C array), where the user can retrieve a privatized copy by the privatization
    id, the index into the table. Each copy will share the same privatization id so that it can be used across
    multiple locales; all locales will create a privatized copy, even the ones that the data structure is not
    intended to be distributed over. Calling `_newPrivatizedClass(this)` will create a privatized copy on each
    locale. Calling `chpl_getPrivatizedClass(this.type, pid)` where `pid` is the privatization id, will obtain
    the privatized instance for the current node to work on. Be aware that you must always access data through
    the privatized instance for performance sake, and that privatized instances, after creation, can be mutated
    independently of each other.

    Note also: arrays make use of a specific compiler-optimization for their record-wrappers called 'remote value
    forwarding' where the record is used by value in `forall` and `coforall` loops, rather than by reference.
    Since this is currently hard-coded for Chapel's arrays and domains, the user must manually make a copy of the
    record-wrapper to prevent it from being used by-reference, thereby negating the whole point of privatization.
    Hint: A reference to a remote object is treated as a wide pointer.
  */
  pragma "always RVF"
  record AdjListHyperGraph {
    // Instance of our AdjListHyperGraphImpl from node that created the record
    var instance;
    // Privatization Id
    var pid = -1;

    proc _value {
      if pid == -1 {
        halt("AdjListHyperGraph is uninitialized...");
      }

      return if AdjListHyperGraphDisablePrivatization then instance else chpl_getPrivatizedCopy(instance.type, pid);
    }

    proc init(numVertices : integral, numEdges : integral) {
      init(numVertices, numEdges, new unmanaged DefaultDist, new unmanaged DefaultDist);
    }

    proc init(numVertices : integral, numEdges : integral, mapping) {
      init(numVertices, numEdges, mapping, mapping);
    }

    proc init(
      // Number of vertices
      numVertices : integral,
      // Number of edges
      numEdges : integral,
      // Distribution of vertices
      verticesMappings, 
      // Distribution of edges
      edgesMappings
    ) {
      instance = new unmanaged AdjListHyperGraphImpl(
        numVertices, numEdges, verticesMappings, edgesMappings
      );
      pid = instance.pid;
    }

    proc init(
      propMap : PropertyMap(?vPropType, ?ePropType), 
      vertexMappings = new unmanaged DefaultDist, 
      edgeMappings = new unmanaged DefaultDist
    ) {
      instance = new unmanaged AdjListHyperGraphImpl(
        propMap, vertexMappings, edgeMappings
      );
      pid = instance.pid;
    }
    
    proc init(other : AdjListHyperGraph) {
      instance = other.instance;
      pid = other.pid;
    }

    // TODO: Copy initializer produces an internal compiler error (compilation error after codegen),
    // COde that causes it: init(other.numVertices, other.numEdges, other.verticesDist)
    proc clone(other : this.type) {
      instance = new unmanaged AdjListHyperGraphImpl(other._value);
      pid = instance.pid;
    }
    
    proc destroy() {
      if pid == -1 then halt("Attempt to destroy 'AdjListHyperGraph' which is not initialized...");
      coforall loc in Locales do on loc {
        delete chpl_getPrivatizedCopy(instance.type, pid);
      }
      pid = -1;
      instance = nil;
    }

    forwarding _value;
  }

  // TODO: Improve space-complexity so we do not read all of file into memory.
  // TODO: Improve time-complexity so that we read in the graph in a distributed way
  proc fromAdjacencyList(fileName : string, separator = ",", map : ?t = new unmanaged DefaultDist) throws {
    var f = open(fileName, iomode.r);
    var r = f.reader();
    var vertices : [0..-1] int;
    var edges : [0..-1] int;

    for line in f.lines() {
      var (v,e) : 2 * int;
      var split = line.split(separator);
      if line == "" then continue;
      vertices.push_back(split[1] : int);
      edges.push_back(split[2] : int);
    }

    // Read in minimum and maximum
    var (vMin, vMax) = (max(int(64)), min(int(64)));
    var (eMin, eMax) =  (max(int(64)), min(int(64)));
    for (v,e) in zip(vertices, edges) {
      vMin = min(vMin, v);
      vMax = max(vMax, v);
      eMin = min(eMin, e);
      eMax = max(eMax, e);
    }

    // Convert to 0-based
    vertices -= vMin;
    edges -= eMin;

    // Initialize with data given...
    var graph = new AdjListHyperGraph(vMax - vMin + 1, eMax - eMin + 1, map);

    // Add inclusions...
    forall (v,e) in zip(vertices, edges) {
      graph.addInclusion(v,e);
    }

    return graph;
  }

  pragma "default intent is ref"
  record Lock {
    // Profiling for contended access...
    var contentionCnt : atomic int(64);
    var _lock$ : sync bool;

    inline proc acquire() {
      _lock$ = true;
    }

    inline proc release() {
      _lock$;
    }
  }

  proc acquireLocks(ref a : Lock, ref b : Lock) {
    if a.locale.id > b.locale.id || __primitive("cast", uint(64), __primitive("_wide_get_addr", a)) > __primitive("cast", uint(64), __primitive("_wide_get_addr", b)) {
      if a.locale != here && b.locale != here && a.locale == b.locale {
        on a {
          a.acquire();
          b.acquire();
        }
      } else {
        a.acquire();
        b.acquire();
      }
    } else {
      if a.locale != here && b.locale != here && a.locale == b.locale {
        on b {
          b.acquire();
          a.acquire();
        }
      } else {
        b.acquire();
        a.acquire();
      }
    }
  }

  proc releaseLocks(ref a : Lock, ref b : Lock) {
    if a.locale.id > b.locale.id || __primitive("cast", uint(64), __primitive("_wide_get_addr", a)) > __primitive("cast", uint(64), __primitive("_wide_get_addr", b)) {
      if a.locale != here && b.locale != here && a.locale == b.locale {
        on a {
          a.release();
          b.release();
        }
      } else {
        a.release();
        b.release();
      }
    } else {
      if a.locale != here && b.locale != here && a.locale == b.locale {
        on b {
          b.release();
          a.release();
        }
      } else {
        b.release();
        a.release();
      }
    }
  }

  /*
    NodeData: stores the neighbor list of a node.

    This record should really be private, and its functionality should be
    exposed by public functions.

    TODO: Add this node's id so that it can be used for locking order.
  */
  class NodeData {
    type nodeIdType;
    type propertyType;
    var property : propertyType;
    var incidentDomain = {0..1};
    var incident: [incidentDomain] nodeIdType;
    var lock : Lock;
    var isSorted : bool;
    var size : atomic int;

    proc init(type nodeIdType, property : ?propertyType) {
      this.init(nodeIdType, propertyType);
      this.property = property;
    }

    proc init(type nodeIdType, type propertyType) {
      this.nodeIdType = nodeIdType;
      this.propertyType = propertyType;
    }

    proc init(other : NodeData(?nodeIdType, ?propertyType)) {
      this.nodeIdType = nodeIdType;
      this.propertyType = propertyType;
      complete();

      on other {
        other.lock.acquire();

        this.property = other.property;
        this.incidentDomain = other.incidentDomain;
        this.isSorted = other.isSorted;
        this.size.write(other.size.read());
        this.incident[0..#size.read()] = other.incident[0..#other.size.read()];

        other.lock.release();
      }
    }
    
    proc equals(other : this.type, param acquireLock = true) {
      if degree != other.degree then return false;
      if acquireLock then acquireLocks(lock, other.lock);

      sortIncidence();
      other.sortIncidence();
      var retval = incident[0..#size.read()].equals(other.incident[0..#other.size.read()]);
      
      if acquireLock then releaseLocks(lock, other.lock);
      return retval;
    }

    // Removes duplicates... sorts the incident list before doing so
    proc makeDistinct(param acquireLock = true) {
      if degree <= 1 then return 0;
      
      var incidenceRemoved = 0;
      on this {
        if acquireLock then lock.acquire();
        
        var deg = degree;
        sortIncidence();
        var newDom = {0..#size.read()};
        var newIncident : [newDom] nodeIdType;
        var oldIdx : int;
        var newIdx : int;
        newIncident[newIdx] = incident[oldIdx];
        oldIdx += 1;
        while (oldIdx < deg) {
          if incident[oldIdx] != newIncident[newIdx] {
            newIdx += 1;
            newIncident[newIdx] = incident[oldIdx];
          }
          oldIdx += 1;
        }
        
        incidenceRemoved = deg - (newIdx + 1);
        incidentDomain = {0..newIdx};
        incident = newIncident[0..newIdx];
        size.write(newIdx + 1);
        
        if acquireLock then lock.release();
      }

      return incidenceRemoved;
    }

    // Checks to see if an S-Walk can be performed from this node to other.
    // This is much more lightweight compared to `neighborIntersection` as it
    // will short-circuit and will not create an intersection array.
    proc canWalk(other : this.type, s = 1, param acquireLock = true) {
      if this == other then halt("Attempt to walk on self... May be a bug!");
      if degree < s || other.degree < s then return false;

      if acquireLock then acquireLocks(lock, other.lock);
      sortIncidence();
      other.sortIncidence();

      ref A = this.incident[0..#size.read()];
      ref B = other.incident[0..#other.size.read()];
      var idxA = A.domain.low;
      var idxB = B.domain.low;
      var match : int;
      while idxA <= A.domain.high && idxB <= B.domain.high {
        const a = A[idxA];
        const b = B[idxB];
        if a == b { 
          match += 1;
          if match == s then break;
          idxA += 1; 
          idxB += 1; 
        }
        else if a.id > b.id { 
          idxB += 1;
        } else { 
          idxA += 1;
        }
      }

      if acquireLock then releaseLocks(lock, other.lock);
      
      return match == s;
    }

    // Obtains the intersection of the neighbors of 'this' and 'other'.
    // Associative arrays are extremely inefficient, so we have to roll
    // our own intersection. We do this by sorting both data structures...
    // N.B: This may not perform well in distributed setting, but fine-grained
    // communications may or may not be okay here. Need to profile more.
    proc neighborIntersection(other : this.type, param acquireLock = true) {
      if this == other then halt("Attempt to obtain intersection on self... May be a bug!");
      // Acquire mutual exclusion on both
      if acquireLock then acquireLocks(lock, other.lock);
      sortIncidence();
      other.sortIncidence();

      var intersection : [0..-1] nodeIdType;
      var A = this.incident[0..#size.read()];
      var B = other.incident[0..#other.size.read()];
      var idxA = A.domain.low;
      var idxB = B.domain.low;
      while idxA <= A.domain.high && idxB <= B.domain.high {
        const a = A[idxA];
        const b = B[idxB];
        if a.id == b.id { 
          intersection.push_back(a); 
          idxA += 1; 
          idxB += 1; 
        }
        else if a.id > b.id { 
          idxB += 1;
        } else { 
          idxA += 1;
        }
      }

      if acquireLock then releaseLocks(lock, other.lock);

      return intersection;
    }

    // Sort the incidence list
    proc sortIncidence(param acquireLock = false) {
      on this {
        if acquireLock then lock.acquire();
        if !isSorted {
          sort(incident[0..#size.read()]);
          isSorted = true;
        }
        if acquireLock then lock.release();
      }
    }

    proc isIncident(n : nodeIdType, param acquireLock = true) {
      var retval : bool;
      on this {
        if acquireLock then lock.acquire();

        // Sort if not already
        sortIncidence();

        // Search to determine if it exists...
        retval = search(incident, n, sorted = true)[1];

        if acquireLock then lock.release();
      }

      return retval;
    }

    inline proc isIncident(other) {
      Debug.badArgs(other, nodeIdType);
    }

    inline proc degree {
      return size.read();
    }

    inline proc cap {
      return incidentDomain.high;
    }

    // Resizes the incident list to at least 'sz'
    inline proc resize(sz = cap + 1) {
      var newCap = ceil(cap * 1.5) : int;
      while newCap < sz {
        newCap = ceil(newCap * 1.5) : int;
      }
      incidentDomain = {0..newCap};
    }

    /*
      This method is not parallel-safe with concurrent reads, but it is
      parallel-safe for concurrent writes.
    */
    inline proc addIncidence(ns : nodeIdType, param acquireLock = true) {
      on this {
        if acquireLock then lock.acquire(); // acquire lock
        
        var ix = size.fetchAdd(1);
        if ix > cap {
          resize();
        }
        incident[ix] = ns;
        isSorted = false;

        if acquireLock then lock.release(); // release the lock
      }
    }
    
    // Internal use only!
    proc this(idx : integral) ref {
      if boundsChecking && !incidentDomain.member(idx) {
        halt("Out of Bounds: ", idx, " is not in ", 0..#size);
      }

      return incident[idx];
    }

    iter these() ref {
      for x in incident[0..#size.read()] do yield x;
    }

    iter these(param tag : iterKind) ref where tag == iterKind.standalone {
      forall x in incident[0..#size.read()] do yield x;
    }

    proc readWriteThis(f) {
      on this {
        lock.acquire();
        f <~> new ioLiteral("{ incident = ")
        	<~> these()
        	<~> new ioLiteral(") }");
        lock.release();
      }
    }
  }

  record ArrayWrapper {
    var dom = {0..-1};
    var arr : [dom] int;
  }
  proc ==(a: ArrayWrapper, b: ArrayWrapper) {
    return && reduce (a.arr == b.arr);
  }
  proc !=(a: ArrayWrapper, b: ArrayWrapper) {
    return || reduce (a.arr != b.arr);
  }

  inline proc chpl__defaultHash(r : ArrayWrapper): uint {
    var ret : uint;
    for (ix, a) in zip(r.dom, r.arr) {
      ret = chpl__defaultHashCombine(chpl__defaultHash(a), ret, 1);
    }
    return ret;
  }

  record Vertex {}
  record Edge   {}
  
  pragma "always RVF"
  record Wrapper {
    type nodeType;
    type idType;
    var id: idType;

    /*
      Based on Brad's suggestion:

      https://stackoverflow.com/a/49951164/594274

      The idea is that we can call a function on the type.  In the
      cases where type is instantiated, we will know `nodeType` and
      `idType`, and we can just refer to them in our make method.
    */
    proc type make(id) {
      return new Wrapper(nodeType, idType, id);
    }

    proc type null() {
      return new Wrapper(nodeType, idType, -1);
    }
    
    proc readWriteThis(f) {
      f <~> new ioLiteral("\"")
        <~> nodeType : string
        <~> new ioLiteral("#")
        <~> id
        <~> new ioLiteral("\"");
    }
  }

  proc <(a : Wrapper(?nodeType, ?idType), b : Wrapper(nodeType, idType)) : bool {
    return a.id < b.id;
  }

  proc ==(a : Wrapper(?nodeType, ?idType), b : Wrapper(nodeType, idType)) : bool {
    return a.id == b.id;
  }

  proc >(a : Wrapper(?nodeType, ?idType), b  : Wrapper(nodeType, idType)) : bool {
    return a.id > b.id;
  }

  proc _cast(type t: Wrapper(?nodeType, ?idType), id : integral) {
    return t.make(id : idType);
  }

  proc _cast(type t: Wrapper(?nodeType, ?idType), id : Wrapper(nodeType, idType)) {
    return id;
  }

  inline proc _cast(type t: Wrapper(?nodeType, ?idType), id) {
    compilerError("Bad cast from type ", id.type : string, " to ", t : string, "...");
  }
  proc id ( wrapper ) {
    return wrapper.id;
  }

  enum InclusionType { Vertex, Edge }

  /*
     Adjacency list hypergraph.

     The storage is an array of NodeDatas.  The edges array stores edges, and
     the vertices array stores vertices.  The storage is similar to a
     bidirectional bipartite graph.  Every edge has a set of vertices it
     contains, and every vertex has a set of edges it participates in.  In terms
     of matrix storage, we store CSR and CSC and the same time.  Storing
     strictly CSC or CSR would allow cutting the storage in half, but for now
     the assumption is that having the storage go both ways should allow
     optimizations of certain operations.
  */
  class AdjListHyperGraphImpl {
    var _verticesDomain; // domain of vertices
    var _edgesDomain; // domain of edges
    type _vPropType; // Vertex property
    type _ePropType; // Edge property
  
    // Privatization id
    var pid = -1;

    type vIndexType = index(_verticesDomain);
    type eIndexType = index(_edgesDomain);
    type vDescType = Wrapper(Vertex, vIndexType);
    type eDescType = Wrapper(Edge, eIndexType);

    var _vertices : [_verticesDomain] unmanaged NodeData(eDescType, _vPropType);
    var _edges : [_edgesDomain] unmanaged NodeData(vDescType, _ePropType);
    var _destBuffer = new Aggregator((vIndexType, eIndexType, InclusionType));
    var _propertyMap : PropertyMap(_vPropType, _ePropType);
    var _privatizedVertices = _vertices._value;
    var _privatizedEdges = _edges._value;
    var _privatizedVerticesPID = _vertices.pid;
    var _privatizedEdgesPID = _edges.pid;
    var _masterHandle : unmanaged object;
    var _useAggregation : bool;

    // Initialize a graph with initial domains
    proc init(numVertices = 0, numEdges = 0, vertexMappings, edgeMappings) {
      if numVertices > max(int(AdjListHyperGraphIndexBits)) || numVertices < 0 { 
        halt("numVertices must be between 0..", max(int(AdjListHyperGraphIndexBits)), " but got ", numVertices);
      }
      if numEdges > max(int(AdjListHyperGraphIndexBits)) || numEdges < 0 { 
        halt("numEdges must be between 0..", max(int(AdjListHyperGraphIndexBits)), " but got ", numEdges);
      }

      var verticesDomain = {
        0:int(AdjListHyperGraphIndexBits)..#numVertices:int(AdjListHyperGraphIndexBits)
      } dmapped new dmap(vertexMappings);
      var edgesDomain = {
        0:int(AdjListHyperGraphIndexBits)..#numEdges:int(AdjListHyperGraphIndexBits)
      } dmapped new dmap(edgeMappings);
      this._verticesDomain = verticesDomain;
      this._edgesDomain = edgesDomain;
      this._vPropType = EmptyPropertyMap.vertexPropertyType;
      this._ePropType = EmptyPropertyMap.edgePropertyType;
      this._propertyMap = EmptyPropertyMap;

      complete();

      // Currently bugged 
      forall v in _vertices {
        var node : unmanaged NodeData(eDescType, _vPropType) = new unmanaged NodeData(eDescType, _vPropType);
        v = node;
      }
      forall e in _edges {
        var node : unmanaged NodeData(vDescType, _ePropType) = new unmanaged NodeData(vDescType, _ePropType);
        e = node;
      }

      this.pid = _newPrivatizedClass(_to_unmanaged(this));
    }

    proc init(
      propMap : PropertyMap(?vPropType, ?ePropType), 
      vertexMappings = new unmanaged DefaultDist, 
      edgeMappings = vertexMappings
    ) {
      var verticesDomain = {
        0:int(AdjListHyperGraphIndexBits)..#propMap.numVertexProperties():int(AdjListHyperGraphIndexBits)
      } dmapped new dmap(vertexMappings);
      var edgesDomain = {
        0:int(AdjListHyperGraphIndexBits)..#propMap.numEdgeProperties():int(AdjListHyperGraphIndexBits)
      } dmapped new dmap(edgeMappings);
      this._verticesDomain = verticesDomain;
      this._edgesDomain = edgesDomain;
      this._vPropType = vPropType;
      this._ePropType = ePropType;
      const _tmp = propMap;
      this._propertyMap = _tmp;

      complete();
 
      for (vIdx, vProp) in zip(_verticesDomain, this._propertyMap.vPropMap.dom) {
        on _vertices[vIdx] do _vertices[vIdx] = new unmanaged NodeData(eDescType, vProp);
        _propertyMap.setVertexProperty(vProp, vIdx);
      }

      for (eIdx, eProp) in zip(_edgesDomain, this._propertyMap.ePropMap.dom) {
        on _edges[eIdx] do _edges[eIdx] = new unmanaged NodeData(vDescType, eProp);
        _propertyMap.setEdgeProperty(eProp, eIdx);
      }

      this.pid = _newPrivatizedClass(_to_unmanaged(this));
    }
  
    // Note: Do not create a copy initializer as it is called whenever you create a copy
    // of the object. This is undesirable.
    proc clone(other : AdjListHyperGraphImpl) {
      const verticesDomain = other._verticesDomain;
      const edgesDomain = other._edgesDomain;
      this._verticesDomain = verticesDomain;
      this._edgesDomain = edgesDomain;
      this._vPropType = other._vPropType;
      this._ePropType = other._ePropType;
      this._propertyMap = new PropertyMap(other._propertyMap);

      complete();
      
      forall (ourV, theirV) in zip(this._vertices, other._vertices) do ourV = new unmanaged NodeData(theirV);
      forall (ourE, theirE) in zip(this._edges, other._edges) do ourE = new unmanaged NodeData(theirE);     
      this.pid = _newPrivatizedClass(_to_unmanaged(this));
    }

    proc init(other : AdjListHyperGraphImpl, pid : int(64)) {
      var verticesDomain = other._verticesDomain;
      var edgesDomain = other._edgesDomain;
      verticesDomain.clear();
      edgesDomain.clear();
      this._verticesDomain = verticesDomain;
      this._edgesDomain = edgesDomain;
      this._vPropType = other._vPropType;
      this._ePropType = other._ePropType;
      this._propertyMap = other._propertyMap;

      complete();

      // Obtain privatized instance...
      if other.locale.id == 0 {
        this._masterHandle = _to_unmanaged(other);
        this._privatizedVertices = other._vertices._value;
        this._privatizedEdges = other._edges._value;
        this._destBuffer = other._destBuffer;
      } else {
        assert(other._masterHandle != nil, 
          "Parent not properly privatized on Locale0... here: ", here, ", other: ", other.locale
        );
        this._masterHandle = other._masterHandle;
        var instance = this._masterHandle : this.type;
        this._privatizedVertices = instance._vertices._value;
        this._privatizedEdges = instance._edges._value;
        this._destBuffer = instance._destBuffer;
      }
      this._privatizedVerticesPID = other._privatizedVerticesPID;
      this._privatizedEdgesPID = other._privatizedEdgesPID;
    }
    
    pragma "no doc"
    proc deinit() {
      // Only delete data from master locale
      if this._masterHandle == nil {
        _destBuffer.destroy();
        [v in _verticesDomain] delete _vertices[v];
        [e in _edgesDomain] delete _edges[e];
      }
    }

    pragma "no doc"
    proc dsiPrivatize(pid) {
      return new unmanaged AdjListHyperGraphImpl(this, pid);
    }

    pragma "no doc"
    proc dsiGetPrivatizeData() {
      return pid;
    }

    pragma "no doc"
    inline proc getPrivatizedInstance() {
      return chpl_getPrivatizedCopy(this.type, pid);
    }

    inline proc verticesDomain {
      return _getDomain(_to_unmanaged(_privatizedVertices.dom));
    }

    inline proc localVerticesDomain {
      return verticesDomain.localSubdomain();
    }

    inline proc edgesDomain {
      return _getDomain(_to_unmanaged(_privatizedEdges.dom));
    }

    inline proc localEdgesDomain {
      return edgesDomain.localSubdomain();
    }

    inline proc vertices {
      return _privatizedVertices;
    }

    inline proc edges {
      return _privatizedEdges;
    }

    inline proc getVertex(idx : integral) ref {
      return getVertex(toVertex(idx));
    }

    inline proc getVertex(desc : vDescType) ref {
      return vertices.dsiAccess(desc.id);
    }

    inline proc getVertex(other) {
      Debug.badArgs(other, (vIndexType, vDescType));  
    }

    inline proc getEdge(idx : integral) ref {
      return getEdge(toEdge(idx));
    }

    inline proc getEdge(desc : eDescType) ref {
      return edges.dsiAccess(desc.id);
    }
    
    inline proc getEdge(other) {
      Debug.badArgs(other, (eIndexType, eDescType));  
    }

    inline proc verticesDist {
      return _to_unmanaged(verticesDomain.dist);
    }

    inline proc edgesDist {
      return _to_unmanaged(edgesDomain.dist);
    }

    inline proc useAggregation {
      return _useAggregation;
    }

    inline proc numEdges return edgesDomain.size;
    inline proc numVertices return verticesDomain.size;
    
    inline proc degree(vDesc : vDescType) return getVertex(vDesc).degree;
    inline proc degree(eDesc : eDescType) return getEdge(eDesc).degree;
    inline proc degree(other) {
      Debug.badArgs(other, (vDescType, eDescType));
    }
    
    
    iter walk(eDesc : eDescType, s = 1) : eDescType {
      for v in incidence(eDesc) {
        for e in incidence(v) {
          if eDesc != e && (s == 1 || isConnected(eDesc, e, s)) {
            yield e;
          }
        }
      }
    }

    iter walk(eDesc : eDescType, s = 1, param tag : iterKind) : eDescType where tag == iterKind.standalone {
      forall v in incidence(eDesc) {
        forall e in incidence(v) {
          if eDesc != e && (s == 1 || isConnected(eDesc, e, s)) {
            yield e;
          }
        }
      }
    }

    iter walk(vDesc : vDescType, s = 1) : vDescType {
      for e in incidence(vDesc) {
        for v in incidence(e) {
          if vDesc != v && (s == 1 || isConnected(vDesc, v, s)) {
            yield v;
          }
        }
      }
    }

    iter walk(vDesc : vDescType, s = 1, param tag : iterKind) : vDescType where tag == iterKind.standalone {
      forall e in incidence(vDesc) {
        forall v in incidence(e) {
          if vDesc != v && (s == 1 || isConnected(vDesc, v, s)) {
            yield v;
          }
        }
      }
    }

    iter getToplexes() {
      var notToplex : [edgesDomain] bool;
      for e in getEdges() {
        var n = degree(e);
        if notToplex[e.id] then continue;
        for ee in walk(e, n) {
          if degree(ee) == n && isConnected(e, ee, n) {
            notToplex[ee.id] = true;
          } else {
            notToplex[e.id] = true;
            break;
          }
        }
        if !notToplex[e.id] then yield e;
      }
    }

    iter getToplexes(param tag : iterKind) where tag == iterKind.standalone {
      var notToplex : [edgesDomain] bool;
      forall e in getEdges() {
        var n = degree(e);
        if notToplex[e.id] then continue;
        for ee in walk(e, n) {
          if degree(ee) == n && isConnected(e, ee, n) {
            notToplex[ee.id] = true;
          } else {
            notToplex[e.id] = true;
            break;
          }
        }
        if !notToplex[e.id] then yield e;
      }
    }

    proc getProperty(vDesc : vDescType) : this._propertyMap.vertexPropertyType {
      return getVertex(vDesc).property;
    }

    proc getProperty(eDesc : eDescType) : this._propertyMap.edgePropertyType {
      return getEdge(eDesc).property;
    }

    inline proc getProperty(other) {
      Debug.badArgs(other, (vDescType, eDescType));
    }

    proc collapseVertices() {
      // Enforce on Locale 0 (presumed master locale...)
      if here != Locales[0] {
        halt("Collapse must be performed on master locale #0");
      }

      const __verticesDomain = _verticesDomain;
      var duplicateVertices : [__verticesDomain] atomic int;
      [dup in duplicateVertices] dup.write(-1);
      var newVerticesDomain = __verticesDomain;
      var vertexMappings : [__verticesDomain] int = -1;

      writeln("Collapsing Vertices...");
      // Pass 1: Locate duplicates by performing an s-walk where s is the size of current vertex
      // We impose an ordering on determining what vertex is a duplicate of what. A vertex v is a
      // duplicate of a vertex v' if v.id > v'.id. If there is a vertex v'' such that v''.id > v.id
      // and v''.id < v'.id, that is v.id < v''.id < v'.id, the duplicate marking is still preserved
      // as we can follow v'.id's duplicate to find v''.id's duplicate to find the distinct vertex v.
      {
        writeln("Marking and Deleting Vertices...");
        var vertexSetDomain : domain(ArrayWrapper);
        var vertexSet : [vertexSetDomain] int;
        var l$ : sync bool;
        var numUnique : int;
        forall v in _verticesDomain with (+ reduce numUnique, ref vertexSetDomain, ref vertexSet) {
          var tmp = [e in _vertices[v].incident[0..#_vertices[v].degree]] e.id;
          var vertexArr = new ArrayWrapper();
          vertexArr.dom = {0..#_vertices[v].degree};
          vertexArr.arr = tmp;
          l$ = true;
          vertexSetDomain.add(vertexArr);
          var val = vertexSet[vertexArr];
          if val != 0 {
            delete _vertices[v];
            _vertices[v] = nil;
            duplicateVertices[v].write(val - 1);
            l$;
          } else {
            vertexSet[vertexArr] = v + 1;
            l$;
            numUnique += 1;
          }
        }
        
        newVerticesDomain = {0..#numUnique};
        writeln(
          "Unique Vertices: ", numUnique, 
          ", Duplicate Vertices: ", _verticesDomain.size - numUnique, 
          ", New Vertices Domain: ", newVerticesDomain
        );

        // Verification...
        if Debug.ALHG_DEBUG {
          forall v in _verticesDomain {
            var vv = v;
            while _vertices[vv] == nil {
              vv = duplicateVertices[vv].read();
              assert(vv != -1, "A vertex is nil without a duplicate mapping...");
            }
            var containsVV : bool;
            label outer for e in _vertices[vv].these() {
              for vvv in _edges[e.id] {
                if vvv.id == vv {
                  containsVV = true;
                  break outer;
                }
              }
            }
            if !containsVV {
              writeln("Broken Dual!");
              var vvv = v;
              write("Link: ", toVertex(v));
              while _vertices[vvv] == nil {
                vvv = duplicateVertices[vvv].read();
                write(" -> ", toVertex(vvv));
              }
              writeln();

              writeln("Neighborhood of ", toVertex(vv));
              for e in getVertex(vv) {
                writeln("\t", toEdge(e), ":", [_v in getEdge(e)] _v : string + ",");
              }
            }
          }
        }
      }

      writeln("Moving into temporary array...");
      // Move current array into auxiliary...
      const oldVerticesDom = this._verticesDomain;
      var oldVertices : [oldVerticesDom] unmanaged NodeData(eDescType, _vPropType) = this._vertices;
      this._verticesDomain = newVerticesDomain;

      writeln("Shifting down NodeData for Vertices...");
      // Pass 2: Move down unique NodeData into 'nil' spots. In parallel we will
      // claim indices in the new array via an atomic counter.
      {
        var idx : atomic int;
        forall v in oldVertices.domain {
          if oldVertices[v] != nil {
            var ix = idx.fetchAdd(1);

            // If the locations in the old and new array are the same, we just move it over
            if oldVertices[v].locale == _vertices[ix].locale {
              _vertices[ix] = oldVertices[v];
            } 
            // If the locations are different, we make a copy of the NodeData so that it is local
            // to the new locale.
            else on _vertices[ix] {
              _vertices[ix] = new unmanaged NodeData(oldVertices[v]);
              delete oldVertices[v];
            }

            oldVertices[v] = nil;
            vertexMappings[v] = ix;
          }
        }
        writeln("Shifted down to idx ", idx.read(), " for oldVertices.domain = ", oldVertices.domain);
      }
      
      writeln("Redirecting references to Vertices...");
      // Pass 3: Redirect references to collapsed vertices to new mappings
      {
        forall e in _edges {
          for v in e {
            // If the vertex has been collapsed, first obtain the id of the vertex it was collapsed
            // into, and then obtain the mapping for the collapsed vertex. Otherwise just
            // get the mapping for the unique vertex.
            while duplicateVertices[v.id].read() != -1 {
              v.id = duplicateVertices[v.id].read();
            }
            v.id = vertexMappings[v.id];
          }
        }
      }

      writeln("Updating PropertyMap...");
      // Pass 4: Update PropertyMap
      {
        writeln("Updating PropertyMap for Vertices...");
        for (vProp, vIdx) in _propertyMap.vertexProperties() {
          if vIdx != -1 then _propertyMap.setVertexProperty(vProp, vertexMappings[vIdx]);
        }
      }

      writeln("Removing duplicates: ", removeDuplicates());

      // Obtain duplicate stats...
      var numDupes : [_verticesDomain] atomic int;
      forall vDup in duplicateVertices {
        if vDup.read() != -1 {
          numDupes[vertexMappings[vDup.read()]].add(1);
        }
      }

      var maxDupes = max reduce [n in numDupes] n.read();
      var dupeHistogram : [1..maxDupes] atomic int;
      forall nDupes in numDupes do if nDupes.read() != 0 then dupeHistogram[nDupes.read()].add(1);
      return [n in dupeHistogram] n.read();
    }


    proc collapseEdges() {
      // Enforce on Locale 0 (presumed master locale...)
      if here != Locales[0] {
        // Cannot jump and return as return type is inferred by compiler.
        halt("Collapse must be performed on master locale #0");
      }

      const __edgesDomain = _edgesDomain;
      var duplicateEdges : [__edgesDomain] atomic int;
      [dup in duplicateEdges] dup.write(-1);
      var newEdgesDomain = __edgesDomain;
      var edgeMappings : [__edgesDomain] int = -1;

      

      writeln("Collapsing Edges...");
      // Pass 1: Locate duplicates by performing an s-walk where s is the size of current edge
      // We impose an ordering on determining what edge is a duplicate of what. A edge e is a
      // duplicate of a edge e' if e.id > e'.id. If there is a edge e'' such that e''.id > e.id
      // and e''.id < e'.id, that is e.id < e''.id < e'.id, the duplicate marking is still preserved
      // as we can follow e'.id's duplicate to find e''.id's duplicate to find the distinct edge e.
      {
        writeln("Marking and Deleting Edges...");
        var edgeSetDomain : domain(ArrayWrapper);
        var edgeSet : [edgeSetDomain] int;
        var l$ : sync bool;
        var numUnique : int;
        forall e in _edgesDomain with (+ reduce numUnique, ref edgeSetDomain, ref edgeSet) {
          var tmp = [v in _edges[e].incident[0..#_edges[e].degree]] v.id;
          var edgeArr = new ArrayWrapper();
          edgeArr.dom = {0..#_edges[e].degree};
          edgeArr.arr = tmp;
          l$ = true;
          edgeSetDomain.add(edgeArr);
          var val = edgeSet[edgeArr];
          if val != 0 {
            delete _edges[e];
            _edges[e] = nil;
            duplicateEdges[e].write(val - 1);
            l$;
          } else {
            edgeSet[edgeArr] = e + 1;
            l$;
            numUnique += 1;
          }
        }
        
        newEdgesDomain = {0..#numUnique};
        writeln(
          "Unique Edges: ", numUnique, 
          ", Duplicate Edges: ", _edgesDomain.size - numUnique, 
          ", New Edges Domain: ", newEdgesDomain
        );

        // Verification...
        if Debug.ALHG_DEBUG {
          forall e in _edgesDomain {
            var ee = e;
            while _edges[ee] == nil {
              ee = duplicateEdges[ee].read();
              assert(ee != -1, "An edge is nil without a duplicate mapping...");
            }
            var containsEE : bool;
            label outer for v in _edges[ee].these() {
              for eee in _vertices[v.id] {
                if eee.id == ee {
                  containsEE = true;
                  break outer;
                }
              }
            }

            if !containsEE {
              writeln("Broken Dual!");
              var eee = e;
              write("Link: ", toEdge(e));
              while _edges[eee] == nil {
                eee = duplicateEdges[eee].read();
                write(" -> ", toEdge(eee));
              }
              writeln();

              writeln("Neighborhood of ", toEdge(ee));
              for v in getEdge(ee) {
                writeln("\t", toVertex(v), ":", [_e in getVertex(v)] _e : string + ",");
              }
            }
          }
        }
      }

      writeln("Moving into temporary array...");
      // Move current array into auxiliary...
      const oldEdgesDom = this._edgesDomain;
      var oldEdges : [oldEdgesDom] unmanaged NodeData(vDescType, _ePropType) = this._edges;
      this._edgesDomain = newEdgesDomain;

      writeln("Shifting down NodeData for Edges...");
      // Pass 2: Move down unique NodeData into 'nil' spots. In parallel we will
      // claim indices in the new array via an atomic counter.
      {
        var idx : atomic int;
        forall e in oldEdges.domain {
          if oldEdges[e] != nil {
            var ix = idx.fetchAdd(1);
            
            if oldEdges[e].locale == _edges[ix].locale {
              _edges[ix] = oldEdges[e];
            } else on _edges[ix] {
              _edges[ix] = new unmanaged NodeData(oldEdges[e]);
              delete oldEdges[e];
            }
            
            oldEdges[e] = nil;
            edgeMappings[e] = ix;
          }
        }
        writeln("Shifted down to idx ", idx.read(), " for oldEdges.domain = ", oldEdges.domain);
      }
      
      writeln("Redirecting references to Edges...");
      // Pass 3: Redirect references to collapsed vertices and edges to new mappings
      {
        forall v in _vertices {
          for e in v {
            // If the edge has been collapsed, first obtain the id of the edge it was collapsed
            // into, and then obtain the mapping for the collapsed edge. Otherwise just
            // get the mapping for the unique edge.
            while duplicateEdges[e.id].read() != -1 {
              e.id = duplicateEdges[e.id].read();
            }
            e.id = edgeMappings[e.id];
          }
        }
      }

      writeln("Updating PropertyMap for Edges...");
      // Pass 4: Update PropertyMap
      {
        for (eProp, eIdx) in _propertyMap.edgeProperties() {
          if eIdx != -1 then _propertyMap.setEdgeProperty(eProp, edgeMappings[eIdx]);
        }
      }

      writeln("Removing duplicates: ", removeDuplicates());

      // Obtain duplicate stats...
      var numDupes : [_edgesDomain] atomic int;
      forall eDup in duplicateEdges {
        if eDup.read() != -1 {
          numDupes[edgeMappings[eDup.read()]].add(1);
        }
      }

      var maxDupes = max reduce [n in numDupes] n.read();
      var dupeHistogram : [1..maxDupes] atomic int;
      forall nDupes in numDupes do if nDupes.read() != 0 then dupeHistogram[nDupes.read()].add(1);
      return [n in dupeHistogram] n.read();
    }

    proc collapseSubsets() {
      // Enforce on Locale 0 (presumed master locale...)
      if here != Locales[0] {
        // Cannot jump and return as return type is inferred by compiler.
        halt("Collapse must be performed on master locale #0");
      }

      const __edgesDomain = _edgesDomain;
      var toplexEdges : [__edgesDomain] atomic int;
      [toplex in toplexEdges] toplex.write(-1);
      var newEdgesDomain = __edgesDomain;
      var edgeMappings : [__edgesDomain] int = -1;

      

      writeln("Collapsing Subset...");
      {
        writeln("Marking non-toplex edges...");
        forall e in _edgesDomain do if !toplexEdges[e].read() == -1 {
          label look for v in _edges[e] {
            if toplexEdges[e].read() != -1 then break look;
            for ee in _vertices[v.id] do if e != ee.id && toplexEdges[ee.id].read() == -1 {
              if _edges[e].canWalk(_edges[ee.id], s=_edges[e].degree) {
                if _edges[e].degree > _edges[ee.id].degree {
                  toplexEdges[ee.id].write(e);
                } else if _edges[ee.id].degree > _edges[e].degree {
                  toplexEdges[e].write(ee.id);
                  break look;
                } else if e < ee.id {
                  // Same size, greater priority
                  toplexEdges[ee.id].write(e);
                } else if ee.id > e {
                  toplexEdges[e].write(ee.id);
                }
              }
            }
          }
        }

        writeln("Deleting non-toplex edges...");
        var numToplex : int;
        forall e in _edgesDomain with (+ reduce numToplex) {
          if toplexEdges[e].read() != -1 {
            delete _edges[e];
            _edges[e] = nil;
          } else {
            numToplex += 1;
          }
        }
        
        newEdgesDomain = {0..#numToplex};
        writeln(
          "Toplex Edges: ", numToplex, 
          ", Non-Toplex Edges: ", _edgesDomain.size - numToplex, 
          ", New Edges Domain: ", newEdgesDomain
        );
      }

      writeln("Moving into temporary array...");
      // Move current array into auxiliary...
      const oldEdgesDom = this._edgesDomain;
      var oldEdges : [oldEdgesDom] unmanaged NodeData(vDescType, _ePropType) = this._edges;
      this._edgesDomain = newEdgesDomain;

      writeln("Shifting down NodeData for Edges...");
      // Pass 2: Move down unique NodeData into 'nil' spots. In parallel we will
      // claim indices in the new array via an atomic counter.
      {
        var idx : atomic int;
        forall e in oldEdges.domain {
          if oldEdges[e] != nil {
            var ix = idx.fetchAdd(1);
            
            if oldEdges[e].locale == _edges[ix].locale {
              _edges[ix] = oldEdges[e];
            } else on _edges[ix] {
              _edges[ix] = new unmanaged NodeData(oldEdges[e]);
              delete oldEdges[e];
            }
            
            oldEdges[e] = nil;
            edgeMappings[e] = ix;
          }
        }
        writeln("Shifted down to idx ", idx.read(), " for oldEdges.domain = ", oldEdges.domain);
      }
      
      writeln("Redirecting references to Edges...");
      // Pass 3: Redirect references to collapsed vertices and edges to new mappings
      {
        forall v in _vertices {
          for e in v {
            // If the edge has been collapsed, first obtain the id of the edge it was collapsed
            // into, and then obtain the mapping for the collapsed edge. Otherwise just
            // get the mapping for the unique edge.
            while toplexEdges[e.id].read() != -1 {
              e.id = toplexEdges[e.id].read();
            }
            e.id = edgeMappings[e.id];
          }
        }
      }

      writeln("Updating PropertyMap for Edges...");
      // Pass 4: Update PropertyMap
      {
        for (eProp, eIdx) in _propertyMap.edgeProperties() {
          if eIdx != -1 {
            var toplexId = eIdx;
            while toplexEdges[toplexId].read() != -1 {
              toplexId = toplexEdges[toplexId].read();
            }
            _propertyMap.setEdgeProperty(eProp, edgeMappings[eIdx]);
          } 
        }
      }

      writeln("Removing duplicates: ", removeDuplicates());

      // Obtain toplex stats...
      var numDupes : [_edgesDomain] atomic int;
      forall toplex in toplexEdges {
        if toplex.read() != -1 {
          var toplexId = toplex.read();
          while toplexEdges[toplexId].read() != -1 {
            toplexId = toplexEdges[toplexId].read();
          }
          numDupes[edgeMappings[toplexId]].add(1);
        }
      }

      var maxDupes = max reduce [n in numDupes] n.read();
      var dupeHistogram : [1..maxDupes] atomic int;
      forall nDupes in numDupes do if nDupes.read() != 0 then dupeHistogram[nDupes.read()].add(1);
      return [n in dupeHistogram] n.read();
    }

    proc collapse() {
      var vDupeHistogram = collapseVertices();
      if Debug.ALHG_DEBUG {
        forall v in getVertices() {
          assert(getVertex(v) != nil, "Vertex ", v, " is nil...");
          assert(degree(v) > 0, "Vertex has 0 neighbors...");
          forall e in incidence(v) {
            assert(getEdge(e) != nil, "Edge ", e, " is nil...");
            assert(degree(e) > 0, "Edge has 0 neighbors...");

            var isValid : bool;
            for vv in incidence(e) {
              if vv == v {
                isValid = true;
                break;
              }
            }

            assert(isValid, "Vertex ", v, " has neighbor ", e, " that violates dual property...\nNeighbors = ", incidence(e));
          }
        }

        forall e in getEdges() {
          assert(getEdge(e) != nil, "Edge ", e, " is nil...");
          assert(degree(e) > 0, "Edge has 0 neighbors...");
          forall v in incidence(e) {
            assert(getVertex(v) != nil, "Vertex ", v, " is nil...");
            assert(degree(v) > 0, "Vertex has 0 neighbors...");

            var isValid : bool;
            for ee in incidence(v) {
              if ee == e {
                isValid = true;
                break;
              }
            }

            assert(isValid, "Edge ", e, " has neighbor ", v, " that violates dual property...\n"
             + "Neighbors of ", v, " = ", incidence(v), "\nNeighbors of ", e, " = ", incidence(e));
          }
        }
      }
      
      var eDupeHistogram = collapseEdges();
      if Debug.ALHG_DEBUG {
        forall v in getVertices() {
          assert(getVertex(v) != nil, "Vertex ", v, " is nil...");
          assert(degree(v) > 0, "Vertex has 0 neighbors...");
          forall e in incidence(v) {
            assert(getEdge(e) != nil, "Edge ", e, " is nil...");
            assert(degree(e) > 0, "Edge has 0 neighbors...");

            var isValid : bool;
            for vv in incidence(e) {
              if vv == v {
                isValid = true;
                break;
              }
            }

            assert(isValid, "Vertex ", v, " has neighbor ", e, " that violates dual property...");
          }
        }

        forall e in getEdges() {
          assert(getEdge(e) != nil, "Edge ", e, " is nil...");
          assert(degree(e) > 0, "Edge has 0 neighbors...");
          forall v in incidence(e) {
            assert(getVertex(v) != nil, "Vertex ", v, " is nil...");
            assert(degree(v) > 0, "Vertex has 0 neighbors...");

            var isValid : bool;
            for ee in incidence(v) {
              if ee == e {
                isValid = true;
                break;
              }
            }

            assert(isValid, "Edge ", e, " has neighbor ", v, " that violates dual property...");
          }
        }
      }

      return (vDupeHistogram, eDupeHistogram);
    }

    proc removeIsolatedComponents() {
      // Enforce on Locale 0 (presumed master locale...)
      if here != Locales[0] {
        // Cannot jump and return as return type is inferred by compiler.
        halt("Remove Isolated Components must be performed on master locale #0");
      }

      // Pass 1: Remove isolated components
      writeln("Removing isolated components...");
      var numIsolatedComponents : int;    
      {
        forall e in _edgesDomain with (+ reduce numIsolatedComponents) {
          var n = getEdge(e).degree;
          assert(n > 0, e, " has no neighbors... n=", n);
          if n == 1 {
            var v = getEdge(e)[0];

            assert(getVertex(v) != nil, "A neighbor of ", e, " has an invalid reference ", v);
            var nn = getVertex(v).degree;
            assert(nn > 0, v, " has no neighbors... nn=", nn);
            if nn == 1 {
              _propertyMap.setEdgeProperty(_edges[e].property, -1);
              delete _edges[e];
              _edges[e] = nil;
              
              _propertyMap.setVertexProperty(_vertices[v.id].property, -1);
              delete _vertices[v.id];
              _vertices[v.id] = nil;
              
              numIsolatedComponents += 1;
            }
          }
        }
      }

      const __verticesDomain = _verticesDomain;
      const __edgesDomain = _edgesDomain;
      var vertexMappings : [__verticesDomain] int = -1;
      var edgeMappings : [__edgesDomain] int = -1;
      
      writeln("Moving into temporary array...");
      // Move current array into auxiliary...
      const oldVerticesDom = this._verticesDomain;
      const oldEdgesDom = this._edgesDomain;
      var oldVertices : [oldVerticesDom] unmanaged NodeData(eDescType, _vPropType) = this._vertices;
      var oldEdges : [oldEdgesDom] unmanaged NodeData(vDescType, _ePropType) = this._edges;
      this._verticesDomain = {0..#(oldVerticesDom.size - numIsolatedComponents)};
      this._edgesDomain = {0..#(oldEdgesDom.size - numIsolatedComponents)};

      
      // Pass 2: Shift down non-nil spots...
      writeln("Shifting down NodeData...");
      {
        writeln("Shifting down NodeData for Vertices...");
        var idx : atomic int;
        forall v in oldVerticesDom {
          if oldVertices[v] != nil {
            var ix = idx.fetchAdd(1);
            
            // If the locations in the old and new array are the same, we just move it over
            if oldVertices[v].locale == _vertices[ix].locale {
              _vertices[ix] = oldVertices[v];
            } 
            // If the locations are different, we make a copy of the NodeData so that it is local
            // to the new locale.
            else on _vertices[ix] {
              _vertices[ix] = new unmanaged NodeData(oldVertices[v]);
              delete oldVertices[v];
            }

            oldVertices[v] = nil;
            vertexMappings[v] = ix;
          }
        }
        writeln("Shifted down to idx ", idx.read(), " for oldVertices.domain = ", oldVertices.domain);

        writeln("Shifting down NodeData for Edges...");
        idx.write(0);
        forall e in oldEdgesDom {
          if oldEdges[e] != nil {
            var ix = idx.fetchAdd(1);
            
            if oldEdges[e].locale == _edges[ix].locale {
              _edges[ix] = oldEdges[e];
            } else on _edges[ix] {
              _edges[ix] = new unmanaged NodeData(oldEdges[e]);
              delete oldEdges[e];
            }
            
            oldEdges[e] = nil;
            edgeMappings[e] = ix;
          }
        }
        writeln("Shifted down to idx ", idx.read(), " for oldEdges.domain = ", oldEdges.domain);
      }

      writeln("Redirecting references...");
      // Pass 3: Redirect references to shifted vertices and edges to new mappings
      {
        writeln("Redirecting references for Vertices...");
        forall v in _vertices {
          assert(v != nil, "Vertex is nil... Did not appropriately shift down data...", _verticesDomain);
          for e in v {
            e = edgeMappings[e.id] : eDescType;
          }
        }

        writeln("Redirecting references for Edges...");
        forall e in _edges {
          assert(e != nil, "Edge is nil... Did not appropriately shift down data...", _edgesDomain);
          for v in e {
            v = vertexMappings[v.id] : vDescType;
          }
        }
      }

      writeln("Updating PropertyMap...");
      // Pass 4: Update PropertyMap
      {
        writeln("Updating PropertyMap for Vertices...");
        for (vProp, vIdx) in _propertyMap.vertexProperties() {
          if vIdx != -1 then _propertyMap.setVertexProperty(vProp, vertexMappings[vIdx]);
        }
        
        writeln("Updating PropertyMap for Edges...");
        for (eProp, eIdx) in _propertyMap.edgeProperties() {
          if eIdx != -1 then _propertyMap.setEdgeProperty(eProp, edgeMappings[eIdx]);
        }
      }

      if Debug.ALHG_DEBUG {
        forall v in getVertices() {
          assert(getVertex(v) != nil, "Vertex ", v, " is nil...");
          assert(degree(v) > 0, "Vertex has 0 neighbors...");
          forall e in incidence(v) {
            assert(getEdge(e) != nil, "Edge ", e, " is nil...");
            assert(degree(e) > 0, "Edge has 0 neighbors...");

            var isValid : bool;
            for vv in incidence(e) {
              if vv == v {
                isValid = true;
                break;
              }
            }

            assert(isValid, "Vertex ", v, " has neighbor ", e, " that violates dual property...");
          }
        }

        forall e in getEdges() {
          assert(getEdge(e) != nil, "Edge ", e, " is nil...");
          assert(degree(e) > 0, "Edge has 0 neighbors...");
          forall v in incidence(e) {
            assert(getVertex(v) != nil, "Vertex ", v, " is nil...");
            assert(degree(v) > 0, "Vertex has 0 neighbors...");

            var isValid : bool;
            for ee in incidence(v) {
              if ee == e {
                isValid = true;
                break;
              }
            }

            assert(isValid, "Edge ", e, " has neighbor ", v, " that violates dual property...");
          }
        }
      }

      return numIsolatedComponents;
    }

    iter getToplexes(param tag : iterKind) : eDescType where tag == iterKind.standalone  {
      forall e in getEdges() {
        var isToplex = true;
        for ee in getEdges() {
          if ee != e && !isConnected(e, ee, s=1) {
            isToplex = false;
            break;
          }
        }
        if isToplex then yield e;
      }
    }

    proc isConnected(v1 : vDescType, v2 : vDescType, s) {
      return getVertex(v1).canWalk(getVertex(v2), s);
    }

    proc isConnected(e1 : eDescType, e2 : eDescType, s) {
      return getEdge(e1).canWalk(getEdge(e2), s);
    }

    proc getInclusions() return + reduce getVertexDegrees();

    iter getEdges(param tag : iterKind) where tag == iterKind.standalone {
      forall e in edgesDomain do yield toEdge(e);
    }

    iter getEdges() {
      for e in edgesDomain do yield toEdge(e);
    }

    iter getVertices(param tag : iterKind) where tag == iterKind.standalone {
      forall v in verticesDomain do yield toVertex(v);
    }

    iter getVertices() {
      for v in verticesDomain do yield toVertex(v);
    }

    // Note: this gets called on by a single task...
    // TODO: Need to send back a status saying buffer can be reused
    // but is currently being processed remotely (maybe have a counter
    // determining how many tasks are still processing the buffer), so
    // that user knows when all operations have finished/termination detection.
    inline proc emptyBuffer(buffer : unmanaged Buffer, loc : locale) {
      on loc {
        var buf = buffer.getArray();
        buffer.done();
        var localThis = getPrivatizedInstance();
        local do forall (srcId, destId, srcType) in buf {
          select srcType {
            when InclusionType.Vertex {
              if !localThis.verticesDomain.member(srcId) {
                halt("Vertex out of bounds on locale #", loc.id, ", domain = ", localThis.verticesDomain);
              }
              ref v = localThis.getVertex(srcId);
              if v.locale != here then halt("Expected ", v.locale, ", but got ", here, ", domain = ", localThis.localVerticesDomain, ", with ", (srcId, destId, srcType));
              v.addIncidence(localThis.toEdge(destId), true);
            }
            when InclusionType.Edge {
              if !localThis.edgesDomain.member(srcId) {
                halt("Edge out of bounds on locale #", loc.id, ", domain = ", localThis.edgesDomain);
              }
              ref e = localThis.getEdge(srcId);
              if e.locale != here then halt("Expected ", e.locale, ", but got ", here, ", domain = ", localThis.localEdgesDomain, ", with ", (srcId, destId, srcType));
              e.addIncidence(localThis.toVertex(destId), true);
            }
          }
        }
      }
    }

    proc flushBuffers() {
      forall (buf, loc) in _destBuffer.flushGlobal() {
        emptyBuffer(buf, loc);
      }
    }


    // Resize the edges array
    // This is not parallel safe AFAIK.
    // No checks are performed, and the number of edges can be increased or decreased
    proc resizeEdges(size) {
      edges.setIndices({0..(size-1)});
    }

    // Resize the vertices array
    // This is not parallel safe AFAIK.
    // No checks are performed, and the number of vertices can be increased or decreased
    proc resizeVertices(size) {
      vertices.setIndices({0..(size-1)});
    }

    proc startAggregation() {
      // Must copy on stack to utilize remote-value forwarding
      const _pid = pid;
      coforall loc in Locales do on loc {
        var _this = chpl_getPrivatizedCopy(this.type, _pid);
        _this._useAggregation = true;
      }
    }

    proc stopAggregation() {
      // Must copy on stack to utilize remote-value forwarding
      const _pid = pid;
      coforall loc in Locales do on loc {
        var _this = chpl_getPrivatizedCopy(this.type, _pid);
        _this._useAggregation = false;
      }
    }
  
    /*
      Explicitly aggregate the vertex and element.
    */
    proc addInclusionBuffered(vDesc : vDescType, eDesc : eDescType) {
      // Forward to normal 'addInclusion' if aggregation is disabled
      if AdjListHyperGraphDisableAggregation {
        addInclusion(vDesc, eDesc);
        return;
      }
      
      // Push on local buffers to send later...
      var vLoc = verticesDomain.dist.idxToLocale(vDesc.id);
      var eLoc = edgesDomain.dist.idxToLocale(eDesc.id);
      
      if vLoc == here {
        getVertex(vDesc).addIncidence(eDesc, true);
      } else {
        var vBuf = _destBuffer.aggregate((vDesc.id, eDesc.id, InclusionType.Vertex), vLoc);
        if vBuf != nil {
          begin emptyBuffer(vBuf, vLoc);
        }
      }

      if eLoc == here {
        getEdge(eDesc).addIncidence(vDesc, true);
      } else {
        var eBuf = _destBuffer.aggregate((eDesc.id, vDesc.id, InclusionType.Edge), eLoc);
        if eBuf != nil {
          begin emptyBuffer(eBuf, eLoc);
        }
      }
    }
    
    inline proc addInclusionBuffered(v : vIndexType, e : eIndexType) {
      const vDesc = toVertex(v);
      const eDesc = toEdge(e);
      addInclusionBuffered(vDesc, eDesc);
    }

    inline proc addInclusionBuffered(vDesc : vDescType, e : eIndexType) {
      const eDesc = toEdge(e);
      addInclusionBuffered(vDesc, eDesc);
    }

    inline proc addInclusionBuffered(v : vIndexType, eDesc : eDescType) {
      const vDesc = toVertex(v);
      addInclusionBuffered(vDesc, eDesc);
    }
    
    inline proc addInclusionBuffered(v, e) {
      Debug.badArgs((v, e), ((vIndexType, eIndexType), (vDescType, eDescType), (vIndexType, eDescType), (vDescType, eIndexType)));
    }
    
    /*
      Adds 'e' as a neighbor of 'v' and 'v' as a neighbor of 'e'.
      If aggregation is enabled via 'startAggregation', this will 
      forward to the aggregated version, 'addInclusionBuffered'.
    */
    inline proc addInclusion(vDesc : vDescType, eDesc : eDescType) {
      if !AdjListHyperGraphDisableAggregation && useAggregation {
        addInclusionBuffered(vDesc, eDesc);
        return;
      }
      
      getVertex(vDesc).addIncidence(eDesc, true);
      getEdge(eDesc).addIncidence(vDesc, true);
    }
    
    inline proc addInclusion(v : vIndexType, e : eIndexType) {
      const vDesc = toVertex(v);
      const eDesc = toEdge(e);
      addInclusion(vDesc, eDesc);
    }

    inline proc addInclusion(vDesc : vDescType, e : eIndexType) {
      const eDesc = toEdge(e);
      addInclusion(vDesc, eDesc);
    }

    inline proc addInclusion(v : vIndexType, eDesc : eDescType) {
      const vDesc = toVertex(v);
      addInclusion(vDesc, eDesc);
    }
    
    inline proc addInclusion(v, e) {
      Debug.badArgs((v, e), ((vIndexType, eIndexType), (vDescType, eDescType), (vIndexType, eDescType), (vDescType, eIndexType)));
    }


    proc hasInclusion(v : vIndexType, e : eIndexType) {
      const vDesc = toVertex(v);
      const eDesc = toEdge(e);

      return getVertex(vDesc).hasNeighbor(eDesc);
    }

    proc hasInclusion(vDesc : vDescType, e : eIndexType) {
      const eDesc = toEdge(e);
      return getVertex(vDesc).hasNeighbor(eDesc);
    }

    proc hasInclusion(v : vIndexType, eDesc : eDescType) {
      const vDesc = toVertex(v);
      return getVertex(vDesc).hasNeighbor(eDesc);
    }

    proc hasInclusion(vDesc : vDescType, eDesc : eDescType) {
      return getVertex(vDesc).hasNeighbor(eDesc);     
    }

    proc hasInclusion(v, e) {
      Debug.badArgs((v, e), ((vIndexType, eIndexType), (vDescType, eDescType), (vIndexType, eDescType), (vDescType, eIndexType)));
    }


    proc removeDuplicates() {
      var vertexNeighborsRemoved = 0;
      var edgeNeighborsRemoved = 0;
      forall v in getVertices() with (+ reduce vertexNeighborsRemoved) {
        vertexNeighborsRemoved += getVertex(v).makeDistinct();
      }
      forall e in getEdges() with (+ reduce edgeNeighborsRemoved) {
        edgeNeighborsRemoved += getEdge(e).makeDistinct();
      }
      return (vertexNeighborsRemoved, edgeNeighborsRemoved);
    }

    inline proc toEdge(id : integral) {
      if boundsChecking && !edgesDomain.member(id : eIndexType) {
        halt(id, " is out of range, expected within ", edgesDomain);
      }
      return (id : eIndexType) : eDescType;
    }

    inline proc toEdge(desc : eDescType) {
      return desc;
    }

    // Bad argument...
    inline proc toEdge(other) param {
      Debug.badArgs(other, (eIndexType, eDescType));
    }

    inline proc toVertex(id : integral) {
      if boundsChecking && !verticesDomain.member(id : vIndexType) {
        halt(id, " is out of range, expected within ", verticesDomain);
      }
      return (id : vIndexType) : vDescType;
    }

    inline proc toVertex(desc : vDescType) {
      return desc;
    }

    // Bad argument...
    inline proc toVertex(other) {
      Debug.badArgs(other, (vIndexType, vDescType));
    }
    
    // TODO: Should we add a way to obtain subset of vertex degree and hyperedge cardinality sequences? 
    /*
      Returns vertex degree sequence as array.
    */
    proc getVertexDegrees() {
      const degreeDom = verticesDomain;
      var degreeArr : [degreeDom] int(64);
      // Must be on locale 0 or else we get issues of accessing
      // remote data in local block. Chapel arrays somehow lift
      // this issue for normal array access. Need further investigation...
      on Locales[0] {
        var _this = getPrivatizedInstance();
        forall (degree, v) in zip(degreeArr, _this._vertices) {
          degree = v.degree;
        }
      }
      return degreeArr;
    }

    /*
      Returns hyperedge cardinality sequence as array.
    */
    proc getEdgeDegrees() {
      const degreeDom = edgesDomain;
      var degreeArr : [degreeDom] int(64);
      on Locales[0] {
        var _this = getPrivatizedInstance();
        forall (degree, e) in zip(degreeArr, _this._edges) {
          degree = e.degree;
        }
      }
      return degreeArr;
    }
    
    /*
      Obtain the locale that the given vertex is allocated on
    */
    inline proc getLocale(v : vDescType) : locale {
      return verticesDist.idxToLocale(v.id);
    }
    
    /*
      Obtain the locale that the given edge is allocated on
    */
    inline proc getLocale(e : eDescType) : locale {
      return edgesDist.idxToLocale(e.id);
    }
    
    pragma "no doc"
    inline proc getLocale(other) {
      Debug.badArgs(other, (vDescType, eDescType));
    }

    iter intersection(e1 : eDescType, e2 : eDescType) {
      for n in getEdge(e1).neighborIntersection(getEdge(e2)) do yield n; 
    }

    iter intersection(e1 : eDescType, e2 : eDescType, param tag : iterKind) where tag == iterKind.standalone {
      for n in getEdge(e1).neighborIntersection(getEdge(e2)) do yield n; 
    }

    iter intersection(v1 : vDescType, v2 : vDescType) {
      for n in getVertex(v1).neighborIntersection(getVertex(v2)) do yield n;
    }

    iter intersection(v1 : vDescType, v2 : vDescType, param tag : iterKind) where tag == iterKind.standalone {
      forall n in getVertex(v1).neighborIntersection(getVertex(v2)) do yield n;
    }
    
    inline proc _snapshot(v : vDescType) {
      ref vertex = getVertex(v);
      vertex.lock.acquire();
      var snapshot = vertex.incident[0..#vertex.degree];
      vertex.lock.release();

      return snapshot;
    }

    inline proc _snapshot(e : eDescType) {
      ref edge = getEdge(e);
      edge.lock.acquire();
      var snapshot = edge.incident[0..#edge.degree];
      edge.lock.release();

      return snapshot;
    }

    iter incidence(e : eDescType) {
      for v in _snapshot(e) do yield v;
    }

    iter incidence(e : eDescType, param tag : iterKind) ref where tag == iterKind.standalone {
      forall v in _snapshot(e) do yield v;
    }

    iter incidence(v : vDescType) ref {
      for e in _snapshot(v) do yield e;
    }

    iter incidence(v : vDescType, param tag : iterKind) ref where tag == iterKind.standalone {
      forall e in _snapshot(v) do yield e;
    }

    iter incidence(arg) {
      Debug.badArgs(arg, (vDescType, eDescType));
    }

    iter incidence(arg, param tag : iterKind) where tag == iterKind.standalone {
      Debug.badArgs(arg, (vDescType, eDescType));
    }

    // Iterates over all vertex-edge pairs in graph...
    // N.B: Not safe to mutate while iterating...
    iter these() : (vDescType, eDescType) {
      for v in getVertices() {
        for e in incidence(v) {
          yield (v, e);
        }
      }
    }

    // N.B: Not safe to mutate while iterating...
    iter these(param tag : iterKind) : (vDescType, eDescType) where tag == iterKind.standalone {
      forall v in getVertices() {
        forall e in incidence(v) {
          yield (v, e);
        }
      }
    }
  
    // Return adjacency list snapshot of vertex
    proc this(v : vDescType) {
      var ret = incidence(v);
      return ret;
    }
    
    // Return adjacency list snapshot of edge
    proc this(e : eDescType) {
      var ret = incidence(e);
      return ret;
    }
  } // class Graph
  
  inline proc +=(graph : AdjListHyperGraph, other) {
    graph._value += other;
  }

  inline proc +=(graph : unmanaged AdjListHyperGraphImpl, (v,e) : (graph.vDescType, graph.eDescType)) {
    graph.addInclusion(v,e);
  }
  
  inline proc +=(graph : unmanaged AdjListHyperGraphImpl, (e,v) : (graph.eDescType, graph.vDescType)) {
    graph.addInclusion(v,e);
  }

  inline proc +=(graph : unmanaged AdjListHyperGraphImpl, other) {
    Debug.badArgs(other, (graph.vDescType, graph.eDescType));
  }

  module Debug {
    // Provides a nice error message for when user provides invalid type.
    proc badArgs(bad, type good, param errorDepth = 2) param {
      compilerError("Expected argument of type to be in ", good : string, " but received argument of type ", bad.type : string, errorDepth);
    }

    config param ALHG_DEBUG : bool;

    // Determines whether or not we profile for contention...
    config param ALHG_PROFILE_CONTENTION : bool;
    // L.J: Keeps track of amount of *potential* contended accesses. It is not absolute
    // as we check to see if the lock is held prior to attempting to acquire it.
    var contentionCnt : atomic int;

    inline proc contentionCheck(ref lock : atomic bool) where ALHG_PROFILE_CONTENTION {
      if lock.read() {
        contentionCnt.fetchAdd(1);
      }
    }

    inline proc contentionCheck(ref lock : atomic bool) where !ALHG_PROFILE_CONTENTION {
      // NOP
    }
  }
}
