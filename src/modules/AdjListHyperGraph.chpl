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
  record AdjListHyperGraph {
    // Instance of our AdjListHyperGraphImpl from node that created the record
    var instance;
    // Privatization Id
    var pid = -1;

    proc _value {
      if pid == -1 {
        halt("AdjListHyperGraph is uninitialized...");
      }

      return chpl_getPrivatizedCopy(instance.type, pid);
    }

    proc init(numVertices = 0, numEdges = 0, map : ?t = new DefaultDist) {
      instance = new AdjListHyperGraphImpl(numVertices, numEdges, map);
      pid = instance.pid;
    }
    
    proc init(other) {
      instance = other.instance;
      pid = other.pid;
    }

    // TODO: Copy initializer produces an internal compiler error (compilation error after codegen),
    // COde that causes it: init(other.numVertices, other.numEdges, other.verticesDist)
    proc clone(other) {
      instance = new AdjListHyperGraphImpl(other);
      pid = instance.pid;
    }

    forwarding _value;
  }

  // TODO: Improve space-complexity so we do not read all of file into memory.
  // TODO: Improve time-complexity so that we read in the graph in a distributed way
  proc fromAdjacencyList(fileName : string, separator = ",", map : ?t = new DefaultDist) throws {
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
    // TODO: Profile
    proc neighborIntersection(other : this.type) {
      // Acquire mutual exclusion on both
      serial other.locale != here && this.locale != here do cobegin {
        on this do lock.acquire();
        on other do other.lock.acquire();
      }

      // Possibly remote accesses, copy by value...
      const thisDom = neighborListDom;
      const otherDom = other.neighborListDom;

      var (idxThis, idxOther) = (thisDom.low, otherDom.low);
      var intersection : [1..0] int;
      
      // Perform this operation in N chunks...
      /*
      while idxA <= newA.domain.high && idxB <= newB.domain.high {
        const a = newA[idxA];
        const b = newB[idxB];
        if a == b { intersection.push_back(a); idxA += 1; idxB += 1; }
        else if a > b then idxB += 1;
        else idxA += 1;
      }
      */
      halt("Intersection not yet implemented... TODO");

      cobegin {
        on this {
          lock.release();
        }
        on other {
          other.lock.release();
        }
      }
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

    inline proc hasNeighbor(n) {
      compilerError("Attempt to invoke 'hasNeighbor' with wrong type: ", n.type : string, ", requires type ", nodeIdType : string);
    }

    inline proc numNeighbors {
      return neighborList.size;
    }

    /*
      This method is not parallel-safe with concurrent reads, but it is
      parallel-safe for concurrent writes.
    */
    proc addNodes(vals) {
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
        	<~> new ioLiteral(", lock$ = ")
        	<~> lock.read()
        	<~> new ioLiteral("(isFull: ")
        	<~> lock.read()
        	<~> new ioLiteral(") }");
      }
    }
  } // record

  proc =(ref lhs: NodeData, ref rhs: NodeData) {
    if lhs == rhs then return;

    lhs.lock.acquire();
    rhs.lock.acquire();

    lhs.neighborListDom = rhs.neighborListDom;
    lhs.neighborList = rhs.neighborList;

    rhs.lock.release();
    lhs.lock.release();
  }

  record Vertex {}
  record Edge   {}

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
  }

  proc <(a : Wrapper(?nodeType, ?idType), b : Wrapper(nodeType, idType)) : bool {
    return a.id < b.id;
  }

  proc _cast(type t: Wrapper(?nodeType, ?idType), id : idType) {
    return t.make(id);
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

  // Number of communication buffers to swap out as they are filled...
  config const AdjListHyperGraphNumBuffers = 8;
  // Size of buffer is enough for one megabyte of bulk transfer by default.
  config const AdjListHyperGraphBufferSize = 1024 * 1024; 

  param BUFFER_OK = -1;

  enum DescriptorType { None, Vertex, Edge };

  pragma "default intent is ref"
  record DestinationBuffer {
    type vDescType;
    type eDescType;
    var buffers : [0..#AdjListHyperGraphNumBuffers] [1..AdjListHyperGraphBufferSize] (int(64), int(64), DescriptorType);
    var bufBusy : [0..#AdjListHyperGraphNumBuffers] atomic bool;
    var bufIdx : atomic int;
    var claimed : atomic int;
    var filled : atomic int;

    proc append(src, dest, srcType) : int {
      // Get our buffer slot
      var idx = claimed.fetchAdd(1) + 1;
      while idx > AdjListHyperGraphBufferSize {
        chpl_task_yield();
        idx = claimed.fetchAdd(1) + 1;
      }
      assert(idx > 0);

      const currBufIdx = bufIdx.read();
      ref buffer = buffers[currBufIdx];

      // Fill our buffer slot and notify as filled...
      buffer[idx] = (src, dest, srcType);
      var nFilled = filled.fetchAdd(1) + 1;

      // Check if we filled the buffer...
      if nFilled == AdjListHyperGraphBufferSize {
        // Swap buffer...
        bufBusy[currBufIdx].write(true);
        // TODO: Handle when amount of buffers is 1...
        label outer while true {
          for (ix, busy) in zip(bufBusy.domain, bufBusy) {
            if busy.read() == false {
              bufIdx.write(ix);
              break outer;
            }
          }
          writeln(here, ": Found all buffers busy...");
          chpl_task_yield();
        }

        filled.write(0);
        claimed.write(0);
        
        // Caller must now handle processing this buffer...
        return currBufIdx;
      }

      return BUFFER_OK;
    }
    
    proc finished(idx) {
      clear(idx);
      bufBusy[idx].write(false);
    }

    proc clear(idx) {
      buffers[idx] = (0, 0, DescriptorType.None);
    }

    proc clearAll() {
      forall b in buffers do b = (0, 0, DescriptorType.None);
    }

    proc reset() {
      filled.write(0);
      claimed.write(0);
      clearAll();
    }

    proc awaitCompletion() {
      forall (busy, idx) in zip(bufBusy, bufBusy.domain) {
        var spincnt = 0;
        while busy.read() == true {
          chpl_task_yield();
          spincnt += 1;
          if spincnt > 1024 * 1024 {
            halt("Spunout waiting in ", here.id, " for buffer #", idx);
          }
        }
      }
    }
  }


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

    var _vertices : [_verticesDomain] NodeData(eDescType);
    var _edges : [_edgesDomain] NodeData(vDescType);
    var _destBuffer : [LocaleSpace] DestinationBuffer(vDescType, eDescType);

    var _privatizedVertices = _vertices._value;
    var _privatizedEdges = _edges._value;
    var _privatizedVerticesPID = _vertices.pid;
    var _privatizedEdgesPID = _edges.pid;
    var _masterHandle : object;

    // Initialize a graph with initial domains
    proc init(numVertices = 0, numEdges = 0, map : ?t = new DefaultDist) {
      var verticesDomain = {0..#numVertices} dmapped new dmap(map);
      var edgesDomain = {0..#numEdges} dmapped new dmap(map);
      this._verticesDomain = verticesDomain;
      this._edgesDomain = edgesDomain;

      complete();

      // Fill vertices and edges with default class instances...
      forall v in _vertices do v = new NodeData(eDescType);
      forall e in _edges do e = new NodeData(vDescType);

      // Clear buffer...
      forall buf in this._destBuffer do buf.reset();

      this.pid = _newPrivatizedClass(this);
    }
  
    // Note: Do not create a copy initializer as it is called whenever you create a copy
    // of the object. This is undesirable.
    proc clone(other) {
      const verticesDomain = other._verticesDomain;
      const edgesDomain = other._edgesDomain;
      this._verticesDomain = verticesDomain;
      this._edgesDomain = edgesDomain;

      complete();
      
      forall (ourV, theirV) in zip(this._vertices, other._vertices) do ourV = new NodeData(theirV);
      forall (ourE, theirE) in zip(this._edges, other._edges) do ourE = new NodeData(theirE);     
      
      // Clear buffer...
      forall buf in this._destBuffer do buf.reset();
      this.pid = _newPrivatizedClass(this);
    }

    // creates an array sharing storage with the source array
    // ref x = _getArray(other.vertices._value);
    // could we just store privatized and vertices in separate types?
    // array element access privatizedVertices.dsiAccess(idx)
    // push_back won't work - Need to emulate implementation
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
        this._masterHandle = other;
        this._privatizedVertices = other._vertices._value;
        this._privatizedEdges = other._edges._value;
      } else {
        assert(other._masterHandle != nil, "Parent not properly privatized... Race Condition Detected... here: ", here, ", other: ", other.locale);
        this._masterHandle = other._masterHandle;
        var instance = this._masterHandle : this.type;
        this._privatizedVertices = instance._vertices._value;
        this._privatizedEdges = instance._edges._value;
      }
      this._privatizedVerticesPID = other._privatizedVerticesPID;
      this._privatizedEdgesPID = other._privatizedEdgesPID;

      // Clear buffer...
      forall buf in this._destBuffer do buf.reset();
    }

    pragma "no doc"
    proc dsiPrivatize(pid) {
      return new AdjListHyperGraphImpl(this, pid);
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
      return _getDomain(_privatizedVertices.dom);
    }

    inline proc localVerticesDomain {
      return verticesDomain.localSubdomain();
    }

    inline proc edgesDomain {
      return _getDomain(_privatizedEdges.dom);
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

    inline proc getVertex(idx) ref {
      return vertices.dsiAccess(idx);
    }

    inline proc getVertex(desc : vDescType) ref {
      return getVertex(desc.id);
    }

    inline proc getEdge(idx) ref {
      return edges.dsiAccess(idx);
    }

    inline proc getEdge(desc : eDescType) ref {
      return getEdge(desc.id);
    }

    inline proc verticesDist {
      return verticesDomain.dist;
    }


    inline proc edgesDist {
      return edgesDomain.dist;
    }

    inline proc numEdges return edgesDomain.size;
    inline proc numVertices return verticesDomain.size;
    
    inline proc numNeighbors(vDesc : vDescType) return getVertex(vDesc).numNeighbors;
    inline proc numNeighbors(eDesc : eDescType) return getEdge(eDesc).numNeighbors;
    inline proc numNeighbors(other) {
      compilerError("'numNeighbors(",  other.type : string, ")' is not supported, require either ",
          vDescType : string, " or ", eDescType : string);
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
    inline proc emptyBuffer(locid, bufIdx, ref buffer) {
      on Locales[locid] {
        var localBuffer = buffer.buffers[bufIdx];
        var localThis = getPrivatizedInstance();
        forall (srcId, destId, srcType) in localBuffer {
          select srcType {
            when DescriptorType.Vertex {
              if !localThis.verticesDomain.member(srcId) {
                halt("Vertex out of bounds on locale #", locid, ", domain = ", localThis.verticesDomain);
              }
              ref v = localThis.getVertex(srcId);
              if v.locale != here then halt("Expected ", v.locale, ", but got ", here, ", domain = ", localThis.localVerticesDomain, ", with ", (srcId, destId, srcType));
              v.addNodes(localThis.toEdge(destId));
            }
            when DescriptorType.Edge {
              if !localThis.edgesDomain.member(srcId) {
                halt("Edge out of bounds on locale #", locid, ", domain = ", localThis.edgesDomain);
              }
              ref e = localThis.getEdge(srcId);
              if e.locale != here then halt("Expected ", e.locale, ", but got ", here, ", domain = ", localThis.localEdgesDomain, ", with ", (srcId, destId, srcType));
              e.addNodes(localThis.toVertex(destId));
            }
            when DescriptorType.None {
              // NOP
            }
          }
        }
      }
      // Buffer safe to reuse again...
      buffer.finished(bufIdx);
    }

    proc flushBuffers() {
      // Clear on all locales...
      coforall loc in Locales do on loc {
        const _this = getPrivatizedInstance();
        forall (locid, buf) in zip(LocaleSpace, _this._destBuffer) {
          _this.emptyBuffer(locid, buf.bufIdx.read(), buf);
          buf.awaitCompletion();
        }
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

    proc addInclusionBuffered(v, e) {
      const vDesc = toVertex(v);
      const eDesc = toEdge(e);

      // Push on local buffers to send later...
      var vLocId = verticesDist.idxToLocale(vDesc.id).locale.id;
      var eLocId = edgesDist.idxToLocale(eDesc.id).locale.id;
      ref vBuf =  _destBuffer[vLocId];
      ref eBuf = _destBuffer[eLocId];

      var vStatus = vBuf.append(vDesc.id, eDesc.id, DescriptorType.Vertex);
      if vStatus != BUFFER_OK {
        begin {
          ref _vBuf = vBuf;
          emptyBuffer(vLocId, vStatus,  _vBuf);
        }
      }

      var eStatus = eBuf.append(eDesc.id, vDesc.id, DescriptorType.Edge);
      if eStatus != BUFFER_OK {
        begin {
          ref _eBuf = eBuf;
          emptyBuffer(eLocId, eStatus, _eBuf);
        }
      }
    }


    inline proc addInclusion(v, e) {
      const vDesc = toVertex(v);
      const eDesc = toEdge(e);
      
      // If both vertex and edge are hosted on
      // the same node (common for small cluster or
      // shared-memory) we shouldn't perform a cobegin
      // as they end up spawning more tasks than necessary.
      var vLoc = verticesDist.idxToLocale(vDesc.id).locale;
      var eLoc = edgesDist.idxToLocale(eDesc.id).locale;
      
      // Both not on same node? Ensure that both remote operations are handled remotely
      serial vLoc != here && eLoc != here do
        cobegin {
          getVertex(vDesc).addNodes(eDesc);
          getEdge(eDesc).addNodes(vDesc);
        }
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

    inline proc toEdge(id : eIndexType) {
      if !edgesDomain.member(id) {
        halt(id, " is out of range, expected within ", edgesDomain);
      }
      return id : eDescType;
    }

    inline proc toEdge(desc : eDescType) {
      return desc;
    }

    // Bad argument...
    inline proc toEdge(desc) param {
      compilerError("toEdge(" + desc.type : string + ") is not permitted, required type ", eIndexType : string);
    }

    inline proc toVertex(id : vIndexType) {
      if !verticesDomain.member(id) {
        halt(id, " is out of range, expected within ", verticesDomain);
      }
      return id : vDescType;
    }

    inline proc toVertex(desc : vDescType) {
      return desc;
    }

    // Bad argument...
    inline proc toVertex(desc) param {
      compilerError("toVertex(" + desc.type : string + ") is not permitted, required ", vIndexType : string);
    }

    // Obtains list of all degrees; not thread-safe if resized
    proc getVertexDegrees() {
      // The returned array is mapped over the same domain as the original
      // As well a *copy* of the domain is returned so that any modifications to
      // the original are isolated from the returned array.
      const degreeDom = verticesDomain;
      var degreeArr : [degreeDom] int(64);

      // Note: If set of vertices or its domain has changed this may result in errors
      // hence this is not entirely thread-safe yet...
      forall (degree, v) in zip(degreeArr, vertices) {
        degree = v.neighborList.size;
      }

      return degreeArr;
    }


    // Obtains list of all degrees; not thread-safe if resized
    proc getEdgeDegrees() {
      // The returned array is mapped over the same domain as the original
      // As well a *copy* of the domain is returned so that any modifications to
      // the original are isolated from the returned array.
      const degreeDom = edgesDomain;
      var degreeArr : [degreeDom] int(64);

      // Note: If set of vertices or its domain has changed this may result in errors
      // hence this is not entirely thread-safe yet...
      forall (degree, e) in zip(degreeArr, edges) {
        degree = e.neighborList.size;
      }

      return degreeArr;
    }

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



    iter neighbors(e : eDescType, param tag : iterKind) ref
      where tag == iterKind.standalone {
      forall v in edges[e.id].neighborList do yield v;
    }

    iter neighbors(v : vDescType) ref {
      for e in vertices[v.id].neighborList do yield e;
    }

    iter neighbors(v : vDescType, param tag : iterKind) ref
      where tag == iterKind.standalone {
      forall e in vertices[v.id].neighborList do yield e;
    }

    // Bad argument
    iter neighbors(arg) {
      compilerError("neighbors(" + arg.type : string + ") not supported, "
      + "argument must be of type " + vDescType : string + " or " + eDescType : string);
    }

    // Bad Argument
    iter neighbors(arg, param tag : iterKind) where tag == iterKind.standalone {
      compilerError("neighbors(" + arg.type : string + ") not supported, "
      + "argument must be of type " + vDescType : string + " or " + eDescType : string);
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

  module Debug {
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
