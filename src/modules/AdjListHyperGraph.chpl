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
  
  /*
    Disable aggregation. This will cause all calls to `addInclusionBuffered` to go to `addInclusion` and
    all calls to `flush` to do a NOP.
  */
  config const AdjListHyperGraphDisableAggregation = false;

  /*
    This will forward all calls to the original instance rather than the privatized instance.
  */
  config const AdjListHyperGraphDisablePrivatization = false;

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


    proc init(numVertices = 0, numEdges = 0, map : ?t = new unmanaged DefaultDist) {
      instance = new unmanaged AdjListHyperGraphImpl(numVertices, numEdges, map);
      pid = instance.pid;
    }
    
    proc init(other) {
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

    proc init(type nodeIdType) {
      this.nodeIdType = nodeIdType;
    }

    proc init(other) {
      this.nodeIdType = other.nodeIdType;
      complete();

      on other {
        other.lock.acquire();

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

    // Privatization id
    var pid = -1;

    type vIndexType = index(_verticesDomain);
    type eIndexType = index(_edgesDomain);
    type vDescType = Wrapper(Vertex, vIndexType);
    type eDescType = Wrapper(Edge, eIndexType);

    var _vertices : [_verticesDomain] unmanaged NodeData(eDescType);
    var _edges : [_edgesDomain] unmanaged NodeData(vDescType);
    var _destBuffer = new Aggregator((vIndexType, eIndexType, InclusionType));
    var _privatizedVertices = _vertices._value;
    var _privatizedEdges = _edges._value;
    var _privatizedVerticesPID = _vertices.pid;
    var _privatizedEdgesPID = _edges.pid;
    var _masterHandle : unmanaged object;
    var _useAggregation : bool;

    // Initialize a graph with initial domains
    proc init(numVertices = 0, numEdges = 0, map : ?t = new unmanaged DefaultDist, param indexBits = 32) {
      if numVertices > max(int(indexBits)) || numVertices < 0 { 
        halt("numVertices must be between 0..", max(int(indexBits)), " but got ", numVertices);
      }
      if numEdges > max(int(indexBits)) || numEdges < 0 { 
        halt("numEdges must be between 0..", max(int(indexBits)), " but got ", numEdges);
      }

      var verticesDomain = {0:int(indexBits)..#numVertices:int(indexBits)} dmapped new dmap(map);
      var edgesDomain = {0:int(indexBits)..#numEdges:int(indexBits)} dmapped new dmap(map);
      this._verticesDomain = verticesDomain;
      this._edgesDomain = edgesDomain;

      complete();

      // Currently bugged 
      forall v in _vertices {
        var node : unmanaged NodeData(eDescType) = new unmanaged NodeData(eDescType);
        v = node;
      }
      forall e in _edges {
        var node : unmanaged NodeData(vDescType) = new unmanaged NodeData(vDescType);
        e = node;
      }

      this.pid = _newPrivatizedClass(_to_unmanaged(this));
    }
  
    // Note: Do not create a copy initializer as it is called whenever you create a copy
    // of the object. This is undesirable.
    proc clone(other) {
      const verticesDomain = other._verticesDomain;
      const edgesDomain = other._edgesDomain;
      this._verticesDomain = verticesDomain;
      this._edgesDomain = edgesDomain;

      complete();
      
      forall (ourV, theirV) in zip(this._vertices, other._vertices) do ourV = new unmanaged NodeData(theirV);
      forall (ourE, theirE) in zip(this._edges, other._edges) do ourE = new unmanaged NodeData(theirE);     
      this.pid = _newPrivatizedClass(_to_unmanaged(this));
    }

    proc init(other, pid : int(64)) {
      var verticesDomain = other._verticesDomain;
      var edgesDomain = other._edgesDomain;
      verticesDomain.clear();
      edgesDomain.clear();
      this._verticesDomain = verticesDomain;
      this._edgesDomain = edgesDomain;

      complete();

      // Obtain privatized instance...
      if other.locale.id == 0 {
        this._masterHandle = _to_unmanaged(other);
        this._privatizedVertices = other._vertices._value;
        this._privatizedEdges = other._edges._value;
        this._destBuffer = other._destBuffer;
      } else {
        assert(other._masterHandle != nil, "Parent not properly privatized on Locale0... here: ", here, ", other: ", other.locale);
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
      Debug.badArgs(other, vIndexType, vDescType);  
    }

    inline proc getEdge(idx : integral) ref {
      return getEdge(toEdge(idx));
    }

    inline proc getEdge(desc : eDescType) ref {
      return edges.dsiAccess(desc.id);
    }
    
    inline proc getEdge(other) {
      Debug.badArgs(other, eIndexType, eDescType);  
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
      Debug.badArgs(other, vDescType, eDescType);
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
    proc addInclusionBuffered(v, e) {
      // Forward to normal 'addInclusion' if aggregation is disabled
      if AdjListHyperGraphDisableAggregation {
        addInclusion(v,e);
        return;
      }
      
      const vDesc = toVertex(v);
      const eDesc = toEdge(e);
      

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
    
    /*
      Adds 'e' as a neighbor of 'v' and 'v' as a neighbor of 'e'.
      If aggregation is enabled via 'startAggregation', this will 
      forward to the aggregated version, 'addInclusionBuffered'.
    */
    inline proc addInclusion(v, e) {
      if !AdjListHyperGraphDisableAggregation && useAggregation {
        addInclusionBuffered(v,e);
        return;
      }

      const vDesc = toVertex(v);
      const eDesc = toEdge(e);
      
      getVertex(vDesc).addNodes(eDesc);
      getEdge(eDesc).addNodes(vDesc);
    }

    proc hasInclusion(v, e) {
      const vDesc = toVertex(v);
      const eDesc = toEdge(e);

      return getVertex(vDesc).hasNeighbor(e);
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
      Debug.badArgs(other, eIndexType, eDescType);
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
      Debug.badArgs(other, vIndexType, vDescType);
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
      Debug.badArgs(other, vDescType, eDescType);
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
      Debug.badArgs(arg, vDescType, eDescType);
    }

    // Bad Argument
    iter neighbors(arg, param tag : iterKind) where tag == iterKind.standalone {
      Debug.badArgs(arg, vDescType, eDescType);
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
    Debug.badArgs(other, (graph.vDescType, graph.eDescType), (graph.eDescType, graph.vDescType));
  }

  module Debug {
    // Provides a nice error message for when user provides invalid type.
    proc badArgs(bad, type good...?n) param {
      compilerError("Expected argument of type to be in ", good : string, " but received argument of type ", bad.type : string);
    }

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
