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
  record SpinLockTATAS {
    // Profiling for contended access...
    var contentionCnt : atomic int(64);
    var _lock : atomic bool;

    inline proc acquire() {
      // Fast Path
      if _lock.testAndSet() == false {
        return;
      }

      if Debug.ALHG_PROFILE_CONTENTION {
        contentionCnt.fetchAdd(1);
      }

      // Slow Path
      while true {
        var val = _lock.read();
        if val == false && _lock.testAndSet() == false {
          break;
        }

        chpl_task_yield();
      }
    }

    inline proc release() {
      _lock.clear();
    }
  }

  /*
    NodeData: stores the neighbor list of a node.

    This record should really be private, and its functionality should be
    exposed by public functions.
  */
  class NodeData {
    type nodeIdType;
    type propertyType;
    var property : propertyType;
    var neighborListDom = {0..-1};
    var neighborList: [neighborListDom] nodeIdType;

    // Due to issue with qthreads, we need to keep this as an atomic and implement as a spinlock
    // TODO: Can parameterize this to use SpinLockTAS (Test & Set), SpinlockTATAS (Test & Test & Set),
    // and SyncLock (mutex)...
    var lock : SpinLockTATAS;

    //  Keeps track of whether or not the neighborList is sorted; any insertion must set this to false
    var isSorted : bool;

    // As neighborList is protected by a lock, the size would normally have to be computed in a mutually exclusive way.
    // By keeping a separate counter, it makes it fast and parallel-safe to check for the size of the neighborList.
    var neighborListSize : atomic int;

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
        this.neighborListDom = other.neighborListDom;
        this.neighborList = other.neighborList;
        this.isSorted = other.isSorted;
        this.neighborListSize.write(other.neighborListSize.read());

        other.lock.release();
      }
    }
    
    // Removes duplicates... sorts the neighborlist before doing so
    proc removeDuplicateNeighbors() {
      var neighborsRemoved = 0;
      on this {
        lock.acquire();

        sortNeighbors();

        var newDom = neighborListDom;
        var newNeighbors : [newDom] nodeIdType;
        var oldNeighborIdx = neighborListDom.low;
        var newNeighborIdx = newDom.low;
        if neighborList.size != 0 {
          newNeighbors[newNeighborIdx] = neighborList[newNeighborIdx];
          while (oldNeighborIdx <= neighborListDom.high) {
            if neighborList[oldNeighborIdx] != newNeighbors[newNeighborIdx] {
              newNeighborIdx += 1;
              newNeighbors[newNeighborIdx] = neighborList[oldNeighborIdx];
            }
            oldNeighborIdx += 1;
          }
          
          neighborsRemoved = neighborListDom.high - newNeighborIdx;
          neighborListDom = {newDom.low..newNeighborIdx};
          neighborList = newNeighbors[newDom.low..newNeighborIdx];
        }
        lock.release();
      }
      return neighborsRemoved;
    }

    // Obtains the intersection of the neighbors of 'this' and 'other'.
    // Associative arrays are extremely inefficient, so we have to roll
    // our own intersection. We do this by sorting both data structures...
    // N.B: This may not perform well in distributed setting, but fine-grained
    // communications may or may not be okay here. Need to profile more.
    proc neighborIntersection(other : this.type) {
      if this == other then return this.neighborList;
      // Acquire mutual exclusion on both
      serial other.locale != here && this.locale != here do cobegin {
        on this do lock.acquire();
        on other do other.lock.acquire();
      }

      var intersection : [0..-1] nodeIdType;
      var A = this.neighborList;
      var B = other.neighborList;
      var idxA = A.domain.low;
      var idxB = B.domain.low;
      while idxA <= A.domain.high && idxB <= B.domain.high {
        const a = A[idxA];
        const b = B[idxB];
        if a == b { 
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

      serial other.locale != here && this.locale != here do cobegin {
        on this do lock.release();
        on other do other.lock.release();
      }

      return intersection;
    }

    proc sortNeighbors() {
      on this do if !isSorted {
        sort(neighborList);
        isSorted = true;
      }
    }

    proc hasNeighbor(n : nodeIdType) {
      var retval : bool;
      on this {
        lock.acquire();

        // Sort if not already
        sortNeighbors();

        // Search to determine if it exists...
        retval = search(neighborList, n, sorted = true)[1];

        lock.release();
      }

      return retval;
    }

    inline proc hasNeighbor(other) {
      Debug.badArgs(other, nodeIdType);
    }

    inline proc numNeighbors {
      return neighborList.size;
    }

    /*
      This method is not parallel-safe with concurrent reads, but it is
      parallel-safe for concurrent writes.
    */
    inline proc addNodes(vals) {
      on this {
        lock.acquire(); // acquire lock
        
        neighborList.push_back(vals);
        isSorted = false;

        lock.release(); // release the lock
      }
    }

    proc readWriteThis(f) {
      on this {
        f <~> new ioLiteral("{ neighborListDom = ")
        	<~> neighborListDom
        	<~> new ioLiteral(", neighborlist = ")
        	<~> neighborList
        	<~> new ioLiteral(") }");
      }
    }
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
        delete _vertices;
        delete _edges;
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
    
    inline proc numNeighbors(vDesc : vDescType) return getVertex(vDesc).numNeighbors;
    inline proc numNeighbors(eDesc : eDescType) return getEdge(eDesc).numNeighbors;
    inline proc numNeighbors(other) {
      Debug.badArgs(other, (vDescType, eDescType));
    }

    iter getNeighbors(vDesc : vDescType) : eDescType {
      for e in getVertex(vDesc).neighborList do yield e;
    }

    iter getNeighbors(vDesc : vDescType, param tag : iterKind) : eDescType where tag == iterKind.standalone {
      forall e in getVertex(vDesc).neighborList do yield e;
    }

    iter getNeighbors(eDesc : eDescType) : vDescType {
      for v in getEdge(eDesc).neighborList do yield v; 
    }

    iter getNeighbors(eDesc : eDescType, param tag) : vDescType where tag == iterKind.standalone {
      forall v in getEdge(eDesc).neighborList do yield v;
    }
    
    iter walk(eDesc : eDescType, s = 1) : eDescType {
      for v in getNeighbors(eDesc) {
        for e in getNeighbors(v) {
          if eDesc != e && isConnected(eDesc, e, s) {
            yield e;
          }
        }
      }
    }

    iter walk(eDesc : eDescType, s = 1, param tag : iterKind) : eDescType where tag == iterKind.standalone {
      forall v in getNeighbors(eDesc) {
        forall e in getNeighbors(v) {
          if eDesc != e && isConnected(eDesc, e, s) {
            yield e;
          }
        }
      }
    }

    iter walk(vDesc : vDescType, s = 1) : vDescType {
      for e in getNeighbors(vDesc) {
        for v in getNeighbors(e) {
          if vDesc != v && isConnected(vDesc, v, s) {
            yield v;
          }
        }
      }
    }

    iter walk(vDesc : vDescType, s = 1, param tag : iterKind) : vDescType where tag == iterKind.standalone {
      forall e in getNeighbors(vDesc) {
        forall v in getNeighbors(e) {
          if vDesc != v && isConnected(vDesc, v, s) {
            yield v;
          }
        }
      }
    }

    iter getToplexes() {
      for e in getEdges() {
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
        on Locales[0] do getPrivatizedInstance().collapseVertices();
        return;
      }

      const __verticesDomain = _verticesDomain;
      var duplicateVertices : [__verticesDomain] int = -1;
      var newVerticesDomain = __verticesDomain;
      var vertexMappings : [__verticesDomain] int = -1;

      record _R {
        var d : domain(uint(64));
        var a : [d] Vector(int);
        var l$ : sync bool;
      }
      var vertexSet : _R;

      writeln("Collapsing Vertices...");
      // Pass 1: Collapse Vertices via a hashing the vertex neighborList to eliminate duplicates.
      {
        forall v in _verticesDomain with (ref vertexSet) {
          // Compute hash
          var h : uint(64);
          for e in getVertex(v).neighborList {
            h ^= e.id;
          }

          // Append to hash map
          vertexSet.l$.writeEF(true);
          vertexSet.d.add(h);
          if vertexSet.a[h] == nil {
            vertexSet.a[h] = new unmanaged VectorImpl(int, {0..0});
          }
          vertexSet.a[h].append(v);
          vertexSet.l$.readFE();
        }

        var numUnique : int;
        writeln("Deleting duplicate NodeData for Vertices");
        // Delete all Nodes that are duplicates...
        forall vDup in vertexSet.a with (+ reduce numUnique) {
          if vDup.size() > 1 {
            var vReps : [0..-1] int;
          
            // For each duplicate, map them to the vertex they collapsed into
            label outer for vIdx in 0..#vDup.size() {
              const v = vDup[vIdx];
              
              for (ix, vRep) in zip(vReps.domain, vReps) {
                if getVertex(vRep).neighborList.equals(getVertex(v).neighborList) {
                  duplicateVertices[v] = vRep;
                  _propertyMap.setVertexProperty(getVertex(v).property, vRep);
                  delete _vertices[v];
                  _vertices[v] = nil;
                  continue outer;
                }
              }

              numUnique += 1;
              vReps.push_back(v);
            }
          } else numUnique += 1;
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
            var vv = if _vertices[v] == nil then duplicateVertices[v] else v;
            assert(vv != -1, "A vertex no longer has a valid mapping... ", v, " -> ", vv);
            assert(_vertices[vv] != nil, "A vertex mapping ", v, " -> ", vv, " is nil");
            var containsVV : bool;
            label outer for e in _vertices[vv].neighborList {
              for vvv in _edges[e.id].neighborList {
                if vvv.id == vv {
                  containsVV = true;
                  break outer;
                }
              }
            }
            assert(containsVV, "Broke dual property for ", v);
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
          for v in e.neighborList {
            // If the vertex has been collapsed, first obtain the id of the vertex it was collapsed
            // into, and then obtain the mapping for the collapsed vertex. Otherwise just
            // get the mapping for the unique vertex.
            if duplicateVertices[v.id] != -1 {
              v.id = vertexMappings[duplicateVertices[v.id]];
            } else {
              v.id = vertexMappings[v.id];
            }
          }
        }
      }

      writeln("Updating PropertyMap...");
      // Pass 4: Update PropertyMap
      {
        writeln("Updating PropertyMap for Vertices...");
        for (vProp, vIdx) in _propertyMap.vertexProperties() {
          _propertyMap.setVertexProperty(vProp, vertexMappings[vIdx]);
        }
      }

      writeln("Removing duplicates: ", removeDuplicates());
    }

    proc collapseEdges() {
      // Enforce on Locale 0 (presumed master locale...)
      if here != Locales[0] {
        on Locales[0] do getPrivatizedInstance().collapseEdges();
        return;
      }

      const __edgesDomain = _edgesDomain;
      var duplicateEdges : [__edgesDomain] int = -1;
      var newEdgesDomain = __edgesDomain;
      var edgeMappings : [__edgesDomain] int = -1;

      record _R {
        var d : domain(uint(64));
        var a : [d] Vector(int);
        var l$ : sync bool;
      }
      var edgeSet : _R;

      writeln("Collapsing Edges...");
      // Pass 1: Collapse Edges via a hashing the vertex neighborList to eliminate duplicates.
      {
        forall e in _edgesDomain with (ref edgeSet) {
          // Compute hash
          var h : uint(64);
          for v in getEdge(e).neighborList {
            h ^= v.id;
          }

          // Append to hash map
          edgeSet.l$.writeEF(true);
          edgeSet.d.add(h);
          if edgeSet.a[h] == nil {
            edgeSet.a[h] = new unmanaged VectorImpl(int, {0..0});
          }
          edgeSet.a[h].append(e);
          edgeSet.l$.readFE();
        }

        var numUnique : int;
        writeln("Deleting duplicate NodeData for Edges");
        // Delete all Nodes that are duplicates...
        forall eDup in edgeSet.a with (+ reduce numUnique) {
          if eDup.size() > 1 {
            var eReps : [0..-1] int;
          
            // For each duplicate, map them to the vertex they collapsed into
            label outer for eIdx in 0..#eDup.size() {
              const e = eDup[eIdx];
              
              for (ix, eRep) in zip(eReps.domain, eReps) {
                if getEdge(eRep).neighborList.equals(getEdge(e).neighborList) {
                  duplicateEdges[e] = eRep;
                  _propertyMap.setEdgeProperty(getEdge(e).property, eRep);
                  delete _edges[e];
                  _edges[e] = nil;
                  continue outer;
                }
              }

              numUnique += 1;
              eReps.push_back(e);
            }
          } else numUnique += 1;
        }
        newEdgesDomain = {0..#numUnique};

        writeln(
          "Unique Edges: ", numUnique, 
          ", Duplicate Edges: ", _edgesDomain.size - numUnique, 
          ", New Edges Domain: ", newEdgesDomain
        );

        // Verification
        if Debug.ALHG_DEBUG {
          forall e in _edgesDomain {
            var ee = if _edges[e] == nil then duplicateEdges[e] else e;
            assert(ee != -1, "A edge no longer has a valid mapping... ", e, " -> ", ee);
            assert(_edges[ee] != nil, "A edge mapping ", e, " -> ", ee, " is nil");
            var containsEE : bool;
            label outer for v in _edges[ee].neighborList {
              for eee in _vertices[v.id].neighborList {
                if eee.id == ee {
                  containsEE = true;
                  break outer;
                }
              }
            }
            assert(containsEE, "Broke dual property for ", e);
          }
        }
      };

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
          for e in v.neighborList {
            // If the edge has been collapsed, first obtain the id of the edge it was collapsed
            // into, and then obtain the mapping for the collapsed edge. Otherwise just
            // get the mapping for the unique edge.
            if duplicateEdges[e.id] != -1 {
              e.id = edgeMappings[duplicateEdges[e.id]];
            } else {
              e.id = edgeMappings[e.id];
            }
          }
        }
      }

      writeln("Updating PropertyMap for Edges...");
      // Pass 4: Update PropertyMap
      {
        for (eProp, eIdx) in _propertyMap.edgeProperties() {
          _propertyMap.setEdgeProperty(eProp, edgeMappings[eIdx]);
        }
      }

      writeln("Removing duplicates: ", removeDuplicates());
    }

    proc collapse() {
      collapseVertices();
      if Debug.ALHG_DEBUG {
        forall v in getVertices() {
          assert(getVertex(v) != nil, "Vertex ", v, " is nil...");
          assert(numNeighbors(v) > 0, "Vertex has 0 neighbors...");
          forall e in getNeighbors(v) {
            assert(getEdge(e) != nil, "Edge ", e, " is nil...");
            assert(numNeighbors(e) > 0, "Edge has 0 neighbors...");

            var isValid : bool;
            for vv in getNeighbors(e) {
              if vv == v {
                isValid = true;
                break;
              }
            }

            assert(isValid, "Vertex ", v, " has neighbor ", e, " that violates dual property...\nNeighbors = ", getNeighbors(e));
          }
        }

        forall e in getEdges() {
          assert(getEdge(e) != nil, "Edge ", e, " is nil...");
          assert(numNeighbors(e) > 0, "Edge has 0 neighbors...");
          forall v in getNeighbors(e) {
            assert(getVertex(v) != nil, "Vertex ", v, " is nil...");
            assert(numNeighbors(v) > 0, "Vertex has 0 neighbors...");

            var isValid : bool;
            for ee in getNeighbors(v) {
              if ee == e {
                isValid = true;
                break;
              }
            }

            assert(isValid, "Edge ", e, " has neighbor ", v, " that violates dual property...\n"
             + "Neighbors of ", v, " = ", getNeighbors(v), "\nNeighbors of ", e, " = ", getNeighbors(e));
          }
        }
      }
      collapseEdges();

      if Debug.ALHG_DEBUG {
        forall v in getVertices() {
          assert(getVertex(v) != nil, "Vertex ", v, " is nil...");
          assert(numNeighbors(v) > 0, "Vertex has 0 neighbors...");
          forall e in getNeighbors(v) {
            assert(getEdge(e) != nil, "Edge ", e, " is nil...");
            assert(numNeighbors(e) > 0, "Edge has 0 neighbors...");

            var isValid : bool;
            for vv in getNeighbors(e) {
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
          assert(numNeighbors(e) > 0, "Edge has 0 neighbors...");
          forall v in getNeighbors(e) {
            assert(getVertex(v) != nil, "Vertex ", v, " is nil...");
            assert(numNeighbors(v) > 0, "Vertex has 0 neighbors...");

            var isValid : bool;
            for ee in getNeighbors(v) {
              if ee == e {
                isValid = true;
                break;
              }
            }

            assert(isValid, "Edge ", e, " has neighbor ", v, " that violates dual property...");
          }
        }
      }
    }

    proc removeIsolatedComponents() {
      // Enforce on Locale 0 (presumed master locale...)
      if here != Locales[0] {
        on Locales[0] do getPrivatizedInstance().removeIsolatedComponents();
        return;
      }

      // Pass 1: Remove isolated components
      writeln("Removing isolated components...");
      var numIsolatedComponents : int;    
      {
        forall e in _edgesDomain with (+ reduce numIsolatedComponents) {
          var n = getEdge(e).neighborList.size;
          assert(n > 0, e, " has no neighbors... n=", n);
          if n == 1 {
            var v = getEdge(e).neighborList[0];

            assert(getVertex(v) != nil, "A neighbor of ", e, " has an invalid reference ", v);
            var nn = getVertex(v).neighborList.size;
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
          for e in v.neighborList {
            e = edgeMappings[e.id] : eDescType;
          }
        }

        writeln("Redirecting references for Edges...");
        forall e in _edges {
          assert(e != nil, "Edge is nil... Did not appropriately shift down data...", _edgesDomain);
          for v in e.neighborList {
            v = vertexMappings[v.id] : vDescType;
          }
        }
      }

      writeln("Updating PropertyMap...");
      // Pass 4: Update PropertyMap
      {
        writeln("Updating PropertyMap for Vertices...");
        for (vProp, vIdx) in _propertyMap.vertexProperties() {
          _propertyMap.setVertexProperty(vProp, vertexMappings[vIdx]);
        }
        
        writeln("Updating PropertyMap for Edges...");
        for (eProp, eIdx) in _propertyMap.edgeProperties() {
          _propertyMap.setEdgeProperty(eProp, edgeMappings[eIdx]);
        }
      }
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
      var intersect = intersection(v1, v2);
      return intersect.size >= s;
    }

    proc isConnected(e1 : eDescType, e2 : eDescType, s) {
      var intersect = intersection(e1, e2);
      return intersect.size >= s;
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
              v.addNodes(localThis.toEdge(destId));
            }
            when InclusionType.Edge {
              if !localThis.edgesDomain.member(srcId) {
                halt("Edge out of bounds on locale #", loc.id, ", domain = ", localThis.edgesDomain);
              }
              ref e = localThis.getEdge(srcId);
              if e.locale != here then halt("Expected ", e.locale, ", but got ", here, ", domain = ", localThis.localEdgesDomain, ", with ", (srcId, destId, srcType));
              e.addNodes(localThis.toVertex(destId));
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
        getVertex(vDesc).addNodes(eDesc);
      } else {
        var vBuf = _destBuffer.aggregate((vDesc.id, eDesc.id, InclusionType.Vertex), vLoc);
        if vBuf != nil {
          begin emptyBuffer(vBuf, vLoc);
        }
      }

      if eLoc == here {
        getEdge(eDesc).addNodes(vDesc);
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
      
      getVertex(vDesc).addNodes(eDesc);
      getEdge(eDesc).addNodes(vDesc);
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
        vertexNeighborsRemoved += getVertex(v).removeDuplicateNeighbors();
      }
      forall e in getEdges() with (+ reduce edgeNeighborsRemoved) {
        edgeNeighborsRemoved += getEdge(e).removeDuplicateNeighbors();
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
          degree = v.neighborList.size;
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
          degree = e.neighborList.size;
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
    
    /*
      Utility function to obtain vertices and its degree.
    */
    iter forEachVertexDegree() : (vDescType, int(64)) {
      for (vid, v) in zip(verticesDomain, vertices) {
        yield (vid : vDescType, v.neighborList.size);
      }
    }
    
    iter forEachVertexDegree(param tag : iterKind) : (vDescType, int(64))
    where tag == iterKind.standalone {
      forall (vid, v) in zip(verticesDomain, vertices) {
        yield (toVertex(vid), v.neighborList.size);
      }
    }

    iter forEachEdgeDegree() : (eDescType, int(64)) {
      for (eid, e) in zip(edgesDomain, edges) {
        yield (toEdge(eid), e.neighborList.size);
      }
    }

    iter forEachEdgeDegree(param tag : iterKind) : (eDescType, int(64))
      where tag == iterKind.standalone {
        forall (eid, e) in zip(edgesDomain, edges) {
          yield (toEdge(eid), e.neighborList.size);
        }
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
    
    iter neighbors(e : eDescType) ref {
      for v in getEdge(e).neighborList do yield v;
    }

    iter neighbors(e : eDescType, param tag : iterKind) ref
      where tag == iterKind.standalone {
      forall v in getEdge(e).neighborList do yield v;
    }

    iter neighbors(v : vDescType) ref {
      for e in getVertex(v).neighborList do yield e;
    }

    iter neighbors(v : vDescType, param tag : iterKind) ref
      where tag == iterKind.standalone {
      forall e in getVertex(v).neighborList do yield e;
    }

    // Bad argument
    iter neighbors(arg) {
      Debug.badArgs(arg, (vDescType, eDescType));
    }

    // Bad Argument
    iter neighbors(arg, param tag : iterKind) where tag == iterKind.standalone {
      Debug.badArgs(arg, (vDescType, eDescType));
    }

    // Iterates over all vertex-edge pairs in graph...
    // N.B: Not safe to mutate while iterating...
    iter these() : (vDescType, eDescType) {
      for v in getVertices() {
        for e in getNeighbors(v) {
          yield (v, e);
        }
      }
    }

    // N.B: Not safe to mutate while iterating...
    iter these(param tag : iterKind) : (vDescType, eDescType) where tag == iterKind.standalone {
      forall v in getVertices() {
        forall e in getNeighbors(v) {
          yield (v, e);
        }
      }
    }
  
    // Return adjacency list snapshot of vertex
    proc this(v : vDescType) {
      var ret = getNeighbors(v);
      return ret;
    }
    
    // Return adjacency list snapshot of edge
    proc this(e : eDescType) {
      var ret = getNeighbors(e);
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
