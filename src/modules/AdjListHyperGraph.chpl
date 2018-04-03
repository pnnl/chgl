/* Start at a graph library module.
   This version started out in the SSCA2 benchmark
   and has been modified for the label propagation benchmark.
   Borrowed from the chapel repository. Comes with Cray copyright and Apache license (see the Chapel repo).
 */

// TODO: Intents on arguments?
// TODO: Bulk add of elements to an adjacency list.
// TODO: Graph creation routines.

module AdjListHyperGraph {
  use IO;

  //
  // NodeData: stores the neighbor list of a node.
  //
  /* private */
  record NodeData {
    type nodeIdType;

    var ndom = {0..-1};
    var neighborList: [ndom] nodeIdType;

    proc numNeighbors() return ndom.numIndices;
    var firstAvail$: sync int = 0;

    proc addEdgeOnVertex(to:nodeIdType) {
      on this do {
	// todo: the compiler should make these values local automatically!
	// MZ: The above annotation is from the original code and may be obsolete
	const v = to;

	local {
	  const edgePos = firstAvail$;
	  const prevNdomLen = ndom.high;
	  if edgePos > prevNdomLen {
	    // We grow the array to have exactly as many elements as needed. The original version of this code grew the array by a factor of 2, but that mey require better machinery to access the actually existing adjacencies.
	    ndom = {0..edgePos};
	    // bounds checking below will ensure (edgePos <= ndom.high)
	  }
	  // release the lock
	  firstAvail$ = edgePos + 1;
	  neighborList[edgePos] = v;
	}
      } // on
    }

    proc readWriteThis(f) {
      f <~> new ioLiteral("{ ndom = ") <~> ndom <~> new ioLiteral(", neighborlist = ") <~> neighborList <~> new ioLiteral(", firstAvail$ = ") <~> firstAvail$.readFF() <~> new ioLiteral(" }") <~>  new ioNewline();
    }
  } // record VertexData
  
  record Vertex {}
  record Edge   {}

  record Wrapper {
    type nodeType;
    type idType;
    var id: idType;
  }

  proc id ( wrapper ) {
    return wrapper.id;
  }
  
  /* store a hypergraph 
   */
  class AdjListHyperGraph {
    const vertices_dom; // generic type - domain of vertices
    const edges_dom; // generic type - domain of edges
    
    type vIndexType = index(vertices_dom);
    type eIndexType = index(edges_dom);
    type vType = Wrapper(Vertex, vIndexType);
    type eType = Wrapper(Edge, eIndexType);
    
    var vertices: [vertices_dom] NodeData(vType);
    var edges: [edges_dom] NodeData(eType);
    
    proc Neighbors ( e : eType ) {
      return edges(e.id).neighborList;
    }

    proc Neighbors ( v : vType ) {
      return vertices(v.id).neighborList;
    }

    /* proc readWriteThis(f) { */
    /*   f <~> new ioLiteral("Vertices domain: ") <~> vertices_dom <~> new ioNewline() */
    /* 	<~> new ioLiteral("Vertices: ") <~> vertices <~> new ioNewline() */
    /*     <~> new ioLiteral("Edges domain: ") <~> edges_dom <~> new ioNewline() */
    /* 	<~> new ioLiteral("Edges: ") <~> edges <~> new ioNewline(); */
    /* } */
  } // class Graph
  
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

