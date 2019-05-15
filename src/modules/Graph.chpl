
/*
 Prototype 2-Uniform Hypergraph. Forwards implementation to AdjListHyperGraph and should
 support simple 'addEdge(v1,v2)' and 'forall (v1, v2) in graph.getEdges()'; everything else
 should be forwarded to the underlying Hypergraph.
*/
module Graph {
  use AdjListHyperGraph;
  use Utilities;

  pragma "always RVF"
  record Graph {
    var instance;
    var pid : int = -1;
    
    proc init(numVertices : integral, numEdges : integral) {
      init(numVertices, numEdges, new unmanaged DefaultDist(), new unmanaged DefaultDist());
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
      instance = new unmanaged GraphImpl(
        numVertices, numEdges, verticesMappings, edgesMappings
      );
      pid = instance.pid;
    }

    proc _value {
      if pid == -1 {
        halt("Attempt to use Graph when uninitialized...");
      }

      return chpl_getPrivatizedCopy(instance.type, pid);
    }
    
    proc destroy() {
      if pid == -1 then halt("Attempt to destroy 'Graph' which is not initialized...");
      coforall loc in Locales do on loc {
        delete chpl_getPrivatizedCopy(instance.type, pid);
      }
      pid = -1;
      instance = nil;
    }

    forwarding _value;
  }

  class GraphImpl {
    // privatization id of this
    var pid : int;
    // Hypergraph implementation. The implementation will be privatized before us
    // and so we can 'hijack' its privatization id for when we privatized ourselves.
    var hg;
    // Keep track of edges currently used... Scalable if we have RDMA atomic support,
    // either way it should allow high amounts of concurrency. Note that for now we
    // do not support removing edges from the graph. 
    // TODO: Can allow this by keeping track of a separate counter of inuseEdges and then
    // if inusedEdges < maxNumEdges, use edgeCounter to round-robin for an available edge.
    var edgeCounter;
    type vDescType;

    proc init(numVertices, numEdges, verticesMapping, edgesMapping) {
      hg = new unmanaged AdjListHyperGraphImpl(numVertices, numEdges, verticesMapping, edgesMapping);
      edgeCounter = new unmanaged Centralized(atomic int);
      this.vDescType = hg.vDescType;
      complete();
      this.pid = _newPrivatizedClass(this:unmanaged); 
    }

    proc init(other : GraphImpl, pid : int) {
      this.pid = pid;
      // Grab privatized instance from original hypergraph.
      this.hg = chpl_getPrivatizedCopy(other.hg.type, other.hg.pid); 
      this.edgeCounter = other.edgeCounter;
      this.vDescType = other.vDescType;
    }

    pragma "no doc"
    proc dsiPrivatize(pid) {
      return new unmanaged GraphImpl(this, pid);
    }

    pragma "no doc"
    proc dsiGetPrivatizeData() {
      return pid;
    }

    pragma "no doc"
    inline proc getPrivatizedInstance() {
      return chpl_getPrivatizedCopy(this.type, pid);
    }
    
    proc addEdge(v1 : integral, v2 : integral) {
      addEdge(hg.toVertex(v1), hg.toVertex(v2));
    }

    proc addEdge(v1 : hg.vDescType, v2 : hg.vDescType) {
       var eIdx = edgeCounter.fetchAdd(1);
       if eIdx >= hg.edgesDomain.size {
         halt("Out of Edges! Ability to grow coming soon!");
       }
       var e = hg.toEdge(eIdx);
       hg.addInclusion(v1, e);
       hg.addInclusion(v2, e);
    }

    iter getEdges() : (hg.vDescType, hg.vDescType) {
      for e in hg.getEdges() {
        var sz = hg.getEdge(e).size.read();
        if sz > 2 {
          halt("Edge ", e, " is has more than two vertices: ", hg.getEdge(e).incident);
        }
        if sz == 0 {
          continue;
        }

        yield (hg.getEdge(e).incident[0], hg.getEdge(e).incident[1]);
      }
    }
   

    iter getEdges(param tag : iterKind) : (hg.vDescType, hg.vDescType) where tag == iterKind.standalone {
      forall e in hg.getEdges() {
        var sz = hg.getEdge(e).size.read();
        if sz > 2 {
          halt("Edge ", e, " has more than two vertices: ", hg.getEdge(e).incident);
        }
        if sz == 0 {
          continue;
        }

        yield (hg.getEdge(e).incident[0], hg.getEdge(e).incident[1]);
      }
    }

    // Return neighbors of a vertex 'v'
    iter neighbors(v : integral) {
      for v in neighbors(hg.toVertex(v)) do yield v;
    }

    iter neighbors(v : integral, param tag : iterKind) where tag == iterKind.standalone {
      forall vv in neighbors(hg.toVertex(v)) do yield vv;
    }

    iter neighbors(v : hg.vDescType) {
      for vv in hg.walk(v) do yield vv;
    }

    iter neighbors(v : hg.vDescType, param tag : iterKind) where tag == iterKind.standalone {
      forall vv in hg.walk(v) do yield vv;
    }

    proc hasEdge(v1 : integral, v2 : integral) {
      return hasEdge(hg.toVertex(v1), hg.toVertex(v2)); 
    }
    
    proc hasEdge(v1 : integral, v2 : hg.vDescType) {
      return hasEdge(hg.toVertex(v1), v2);
    }

    proc hasEdge(v1 : hg.vDescType, v2 : integral) {
      return hasEdge(v1, hg.toVertex(v2));
    }

    proc hasEdge(v1 : hg.vDescType, v2 : hg.vDescType) {
      return any([v in hg.walk(v1)] v.id == v2.id);
    }

    forwarding hg only toVertex, getVertices, getLocale, verticesDomain;
  }
}
