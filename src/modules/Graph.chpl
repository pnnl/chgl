
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

    proc init(numVertices, numEdges, verticesMapping, edgesMapping) {
      hg = new AdjListHyperGraphImpl(numVertices, numEdges, verticesMapping, edgesMapping);
      edgeCounter = new Centralized(atomic int);
      complete();
      this.pid = _newPrivatizedClass(this:unmanaged); 
    }

    proc init(other : GraphImpl, pid : int) {
      this.pid = pid;
      // Grab privatized instance from original hypergraph.
      this.hg = chpl_getPrivatizedCopy(other.hg.type, other.hg.pid); 
      this.edgeCounter = this.hg.edgeCounter;
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
        var sz = hg.getEdge(e).incidentDom.size;
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
        var sz = hg.getEdge(e).incidentDom.size;
        if sz > 2 {
          halt("Edge ", e, " is has more than two vertices: ", hg.getEdge(e).incident);
        }
        if sz == 0 {
          continue;
        }

        yield (hg.getEdge(e).incident[0], hg.getEdge(e).incident[1]);
      }
    }

    forwarding hg;

  }
}
