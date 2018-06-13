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

// TODO: Intents on arguments?  TODO: Graph creation routines.  More todos in
// the Gitlab issues system.  In general, all but the tiniest todos should
// become issues in Gitlab.


/*
   Some assumptions:

   1. It is assumed that push_back increases the amount of available
   memory by some factor.  The current implementation of push_back
   supports this assumption.  Making this assumption allows us not to
   worry about reallocating the array on every push_back.  If we
   wanted to have more fine-grained control over memory, we will have
   to investigate adding mechanisms to control it.
 */

module AdjListHyperGraph {
  use IO;
  use CyclicDist;
  use List;
  use Sort;
  use Search;

  /*
    Record-Wrapped structure
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
  
    // TODO: Copy initializer produces an internal compiler error (compilation error after codegen),
    // COde that causes it: init(other.numVertices, other.numEdges, other.verticesDist)
    proc init(other) {
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

    proc hasNeighbor(n : nodeIdType) {
      var retval : bool;
      on this {
        lock.acquire();

        // Sort if not already
        if !isSorted {
          sort(neighborList);
          isSorted = true;
        }

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
  config param AdjListHyperGraphNumBuffers = 8;
  // `c_sizeof` is not compile-time param function, need to calculate by hand
  config param OperationDescriptorSize = 24;
  // Size of buffer is enough for one megabyte of bulk transfer by default.
  config param AdjListHyperGraphBufferSize = ((1024 * 1024) / OperationDescriptorSize) : int(64);

  /*
    OperationDescriptor types...
  */
  param OPERATION_NONE = 0;
  param OPERATION_ADD_INCLUSION_VERTEX = 1;
  param OPERATION_ADD_INCLUSION_EDGE = 2;

  record OperationDescriptor {
     var op : int(64);
     /* For AddInclusion */
     var srcId : int(64);
     var destId : int(64);
  }

  /*
    Status of the sendBuffer...
  */
  // Buffer is okay to use and send...
  param BUFFER_OK = 0;
  // Buffer is full and is sending, cannot be used yet...
  param BUFFER_SENDING = 1;
  // Buffer is being sent, but not yet processed... can be used but not yet sent
  param BUFFER_SENT = 2;


  // Each locale will have its own communication buffer, which will handle
  // sending and receiving data. TODO: Add documentation...
  pragma "use default init"
  pragma "default intent is ref"
  record CommunicationBuffers {
    var locid : int(64);
    var sendBuffer :  AdjListHyperGraphNumBuffers * c_ptr(OperationDescriptor);
    var recvBuffer : AdjListHyperGraphNumBuffers * c_ptr(OperationDescriptor);

    // Status of send buffers...
    var bufferStatus : [1..AdjListHyperGraphNumBuffers] atomic int;
    // Index of currently processed buffer...
    var bufferIdx : atomic int;
    // Number of claimed slots of the buffer...
    var claimed : atomic int;
    // Number of filled claimed slots...
    var filled : atomic int;

    // Send data in bulk...
    proc send(idx) {
      const toSend = sendBuffer[idx];
      const toRecv = recvBuffer[idx];
      const sendSize = AdjListHyperGraphBufferSize;
      __primitive("chpl_comm_array_put", toSend[0], locid, toRecv[0], sendSize);
    }

    // Receive data in bulk...
    proc recv(idx) {
      const toSend = sendBuffer[idx];
      const toRecv = recvBuffer[idx];
      const recvSize = AdjListHyperGraphBufferSize;
      __primitive("chpl_comm_array_get", toRecv[0], locid, toSend[0], recvSize);
    }

    // Clear send buffer with default values
    proc zero(idx) {
      const toZero = sendBuffer[idx];
      const zeroSize = AdjListHyperGraphBufferSize * OperationDescriptorSize;
      c_memset(sendBuffer, 0, zeroSize);
    }

    // Appends operation descriptor to appropriate communication buffer. If buffer
    // is full, the task that was the last to fill the buffer will handle switching
    // out the current buffer and sending the full buffer. If the return value is
    // not 0, then it is index of the buffer that was sent but needs processing...
    proc append(op) : int {
      // Obtain our buffer slot; if we get an index out of bounds, we must wait
      // until the buffer has been swapped out by another thread...
      var idx = claimed.fetchAdd(1) + 1;
      while idx > AdjListHyperGraphBufferSize {
        chpl_task_yield();
        idx = claimed.fetchAdd(1) + 1;
      }
      assert(idx > 0);

      // We have a position in the buffer, now obtain the current buffer. The current
      // buffer will not be swapped out until we finish our operation, as we do not
      // notify that we have filled the buffer until after, which has a full memory
      // barrier. TODO: Relax the read of bufIdx?
      const bufIdx = bufferIdx.read();
      sendBuffer[bufIdx][idx] = op;
      const nFilled = filled.fetchAdd(1) + 1;

      // If we have filled the buffer, we are in charge of swapping them out...
      if nFilled == AdjListHyperGraphBufferSize {
        if AdjListHyperGraphNumBuffers <= 1 {
          halt("Logic unimplemented for AdjListHyperGraphNumBuffers == ", AdjListHyperGraphNumBuffers);
        }

        // If a pending operation has not finished, wait for it then claim it...
        while bufferStatus[bufIdx].read() != BUFFER_OK do chpl_task_yield();
        bufferStatus[bufIdx].write(BUFFER_SENDING);

        // Poll for a buffer not currently sending...
        var newBufIdx = bufIdx + 1;
        while true {
          if newBufIdx > AdjListHyperGraphNumBuffers {
            newBufIdx = 1;
            chpl_task_yield();
          }

          if newBufIdx != bufIdx && bufferStatus[newBufIdx].read() != BUFFER_SENDING {
            break;
          }
          newBufIdx += 1;
        }


        // Set as new buffer...
        bufferIdx.write(newBufIdx);
        filled.write(0);
        claimed.write(0);

        // Send buffer...
        send(bufIdx);
        bufferStatus[bufIdx].write(BUFFER_SENT);

        // Returns buffer needing to be processed on target locale...
        return bufIdx;
      }

      // Nothing needs to be done...
      return 0;
    }

    // Indicates that the buffer has been processed appropriate, freeing up its use.
    proc processed(idx) {
      bufferStatus[idx].write(BUFFER_OK);
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

    // Privatization idi
    var pid = -1;

    type vIndexType = index(_verticesDomain);
    type eIndexType = index(_edgesDomain);
    type vDescType = Wrapper(Vertex, vIndexType);
    type eDescType = Wrapper(Edge, eIndexType);

    var _vertices : [_verticesDomain] NodeData(eDescType);
    var _edges : [_edgesDomain] NodeData(vDescType);
    var _commMatrix : [{0..#numLocales, 0..#numLocales}] CommunicationBuffers;

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

      // TODO: Setup matrix
      this.pid = _newPrivatizedClass(this);
    }
  
    // Copy initializer...
    proc init(other) {
      const verticesDomain = other._verticesDomain;
      const edgesDomain = other._edgesDomain;
      this._verticesDomain = verticesDomain;
      this._edgesDomain = edgesDomain;

      complete();
      
      forall (ourV, theirV) in zip(this._vertices, other._vertices) do ourV = new NodeData(theirV);
      forall (ourE, theirE) in zip(this._edges, other._edges) do ourE = new NodeData(theirE);     
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
        this._masterHandle = other._masterHandle;
        var instance = this._masterHandle : this.type;
        this._privatizedVertices = instance._vertices._value;
        this._privatizedEdges = instance._edges._value;
      }
      this._privatizedVerticesPID = other._privatizedVerticesPID;
      this._privatizedEdgesPID = other._privatizedEdgesPID;

      // TODO: Setup matrix
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

    inline proc vertex(idx) ref {
      return vertices.dsiAccess(idx);
    }

    inline proc vertex(desc : vDescType) ref {
      return vertex(desc.id);
    }

    inline proc edge(idx) ref {
      return edges.dsiAccess(idx);
    }

    inline proc edge(desc : eDescType) ref {
      return edge(desc.id);
    }

    inline proc verticesDist {
      return verticesDomain.dist;
    }


    inline proc edgesDist {
      return edgesDomain.dist;
    }

    inline proc numEdges return edgesDomain.size;
    inline proc numVertices return verticesDomain.size;

    iter getNeighbors(vDesc : vDescType) : eDescType {
      for e in vertex(vDesc).neighborList do yield e;
    }

    iter getNeighbors(vDesc : vDescType, param tag : iterKind) : eDescType where tag == iterKind.standalone {
      forall e in vertex(vDesc).neighborList do yield e;
    }

    iter getNeighbors(eDesc : eDescType) : vDescType {
      for v in edge(eDesc).neighborList do yield v;
    }

    iter getNeighbors(eDesc : eDescType, param tag) : vDescType where tag == iterKind.standalone {
      forall v in edge(eDesc).neighborList do yield v;
    }

    proc getInclusions() return + reduce getVertexDegrees();

    iter getEdges(param tag : iterKind) where tag == iterKind.standalone {
      forall e in edgesDomain do yield e;
    }

    iter getEdges() {
      for e in edgesDomain do yield e;
    }

    iter getVertices(param tag : iterKind) where tag == iterKind.standalone {
      forall v in verticesDomain do yield v;
    }

    iter getVertices() {
      for v in verticesDomain do yield v;
    }

    // Note: this gets called on by a single task...
    inline proc emptyBuffer(srcId, destId) {
      on Locales[destId] {
        // TODO: Handle operating on _commMatrix[srcId, destId]...
      }
    }

    proc flushBuffers() {
      // Clear on all locales...
      coforall loc in Locales do on loc {
        const _this = getPrivatizedInstance();
        forall (src, dest) in _commMatrix.domain {
          emptyBuffer(src, dest);
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
      const vDesc = v : vDescType;
      const eDesc = e : eDescType;
      const vOpDesc = new OperationDescriptor(OPERATION_ADD_INCLUSION_VERTEX, vDesc.id, eDesc.id);
      const eOpDesc = new OperationDescriptor(OPERATION_ADD_INCLUSION_EDGE, eDesc.id, vDesc.id);

      // Push on local buffers to send later...
      const vLocId = vertex(vDesc.id).locale.id;
      const eLocId = edge(eDesc.id).locale.id;
      ref vBuf =  _commMatrix[here.id, vLocId];
      ref eBuf = _commMatrix[here.id, eLocId];

      var vStatus = vBuf.append(vOpDesc);
      if vStatus != 0 {
        emptyBuffer(here.id, vStatus);
        vBuf.processed(vStatus);
      }

      var eStatus = eBuf.append(eOpDesc);
      if eStatus != 0 {
        emptyBuffer(here.id, eStatus);
        eBuf.processed(eStatus);
      }
    }

    inline proc addInclusion(v, e) {
      const vDesc = toVertex(v);
      const eDesc = toEdge(e);

      vertex(vDesc.id).addNodes(eDesc);
      edge(eDesc.id).addNodes(vDesc);
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

    // TODO: Need a better way of getting vertex... right now a lot of casting has to
    // be done and we need to return the index (from its domain) rather than the
    // vertex itself...
    iter forEachVertexDegree() : (vDescType, int(64)) {
      for (vid, v) in zip(verticesDomain, vertices) {
        yield (vid : vDescType, v.neighborList.size);
      }
    }

    iter forEachVertexDegree(param tag : iterKind) : (vDescType, int(64))
    where tag == iterKind.standalone {
      forall (vid, v) in zip(verticesDomain, vertices) {
        yield (vid : vDescType, v.neighborList.size);
      }
    }

    iter forEachEdgeDegree() : (eDescType, int(64)) {
      for (eid, e) in zip(edgesDomain, edges) {
        yield (eid : eDescType, e.neighborList.size);
      }
    }

    iter forEachEdgeDegree(param tag : iterKind) : (eDescType, int(64))
      where tag == iterKind.standalone {
        forall (eid, e) in zip(edgesDomain, edges) {
          yield (eid : eDescType, e.neighborList.size);
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

    // TODO: for something in graph do ...
    iter these() {

    }

    // TODO: forall something in graph do ...
    iter these(param tag : iterKind) where tag == iterKind.standalone {

    }

    // TODO: graph[something] = somethingElse;
    // TODO: Make return ref, const-ref, or by-value versions?
    proc this() {

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

  /* /\* iterate over all neighbor IDs */
  /*  *\/ */
  /* private iter Neighbors( nodes, node : index (nodes.domain) ) { */
  /*   for nlElm in nodes(node).neighborList do */
  /*     yield nlElm(1); // todo -- use nid */
  /* } */

  /* /\* iterate over all neighbor IDs */
  /*  *\/ */
  /* iter private Neighbors( nodes, node : index (nodes), param tag: iterKind) */
  /*   where tag == iterKind.leader { */
  /*   for block in nodes(v).neighborList._value.these(tag) do */
  /*     yield block; */
  /* } */

  /* /\* iterate over all neighbor IDs */
  /*  *\/ */
  /* iter private Neighbors( nodes, node : index (nodes), param tag: iterKind, followThis) */
  /*   where tag == iterKind.follower { */
  /*   for nlElm in nodes(v).neighborList._value.these(tag, followThis) do */
  /*     yield nElm(1); */
  /* } */

  /* /\* return the number of neighbors */
  /*  *\/ */
  /* proc n_Neighbors (nodes, node : index (nodes) )  */
  /*   {return Row (v).numNeighbors();} */


  /*   /\* how to use Graph: e.g. */
  /*      const vertex_domain =  */
  /*      if DISTRIBUTION_TYPE == "BLOCK" then */
  /*      {1..N_VERTICES} dmapped Block ( {1..N_VERTICES} ) */
  /*      else */
  /*      {1..N_VERTICES} ; */

  /*      writeln("allocating Associative_Graph"); */
  /*      var G = new Graph (vertex_domain); */
  /*   *\/ */

  /*   /\* Helps to construct a graph from row, column, value */
  /*      format.  */
  /*   *\/ */
  /* proc buildUndirectedGraph(triples, param weighted:bool, vertices) where */
  /*   isRecordType(triples.eltType) */
  /*   { */

  /*     // sync version, one-pass, but leaves 0s in graph */
  /*     /\* */
  /* 	var r: triples.eltType; */
  /* 	var G = new Graph(nodeIdType = r.to.type, */
  /* 	edgeWeightType = r.weight.type, */
  /* 	vertices = vertices); */
  /* 	var firstAvailNeighbor$: [vertices] sync int = G.initialFirstAvail; */
  /* 	forall trip in triples { */
  /*       var u = trip.from; */
  /*       var v = trip.to; */
  /*       var w = trip.weight; */
  /*       // Both the vertex and firstAvail must be passed by reference. */
  /*       // TODO: possibly compute how many neighbors the vertex has, first. */
  /*       // Then allocate that big of a neighbor list right away. */
  /*       // That way there will be no need for a sync, just an atomic. */
  /*       G.Row[u].addEdgeOnVertex(v, w, firstAvailNeighbor$[u]); */
  /*       G.Row[v].addEdgeOnVertex(u, w, firstAvailNeighbor$[v]); */
  /* 	}*\/ */

  /*     // atomic version, tidier */
  /*     var r: triples.eltType; */
  /*     var G = new Graph(nodeIdType = r.to.type, */
  /*                       edgeWeightType = r.weight.type, */
  /*                       vertices = vertices, */
  /*                       initialLastAvail=0); */
  /*     var next$: [vertices] atomic int; */

  /*     forall x in next$ { */
  /*       next$.write(G.initialFirstAvail); */
  /*     } */

  /*     // Pass 1: count. */
  /*     forall trip in triples { */
  /*       var u = trip.from; */
  /*       var v = trip.to; */
  /*       var w = trip.weight; */
  /*       // edge from u to v will be represented in both u and v's edge */
  /*       // lists */
  /*       next$[u].add(1, memory_order_relaxed); */
  /*       next$[v].add(1, memory_order_relaxed); */
  /*     } */
  /*     // resize the edge lists */
  /*     forall v in vertices { */
  /*       var min = G.initialFirstAvail; */
  /*       var max = next$[v].read(memory_order_relaxed) - 1;  */
  /*       G.Row[v].ndom = {min..max}; */
  /*     } */
  /*     // reset all of the counters. */
  /*     forall x in next$ { */
  /*       next$.write(G.initialFirstAvail, memory_order_relaxed); */
  /*     } */
  /*     // Pass 2: populate. */
  /*     forall trip in triples { */
  /*       var u = trip.from; */
  /*       var v = trip.to; */
  /*       var w = trip.weight; */
  /*       // edge from u to v will be represented in both u and v's edge */
  /*       // lists */
  /*       var uslot = next$[u].fetchAdd(1, memory_order_relaxed); */
  /*       var vslot = next$[v].fetchAdd(1, memory_order_relaxed); */
  /*       G.Row[u].neighborList[uslot] = (v,); */
  /*       G.Row[v].neighborList[vslot] = (u,); */
  /*     } */

  /*     return G; */
  /*   } */
}
