module Butterfly {
  use AdjListHyperGraph;

  proc vertexHasNeighbor(v, e){
    return vertex(toVertex(v)).hasNeighbor(toEdge(e));
  }

  proc getVertexNumButterflies(graph) {
    var butterflyDom = graph.verticesDomain;
    var butterflyArr : [butterflyDom] int(64);
    // Note: If set of vertices or its domain has changed this may result in errors
    // hence this is not entirely thread-safe yet...
    forall (num_butterflies, v) in zip(butterflyArr, graph.verticesDomain) {
      var dist_two_mults : [graph.verticesDomain] int(64); //this is C[w] in the paper, which is the number of distinct distance-two paths that connect v and w
      //C[w] is equivalent to the number of edges that v and w are both connected to
      forall u in graph.vertex(v).neighborList {
        forall w in graph.edge(u).neighborList {
          if w.id != v {
            dist_two_mults[w.id] += 1;
          }
        }
      }
      forall w in dist_two_mults.domain {
        if dist_two_mults[w] > 0 {
          //combinations(dist_two_mults[w], 2) is the number of butterflies that include vertices v and w
          butterflyArr[v] += combinations(dist_two_mults[w], 2);
        }
      }
    }
    return butterflyArr;
  }

  proc getInclusionNumButterflies(v, e){
    var dist_two_mults : [graph.verticesDomain] int(64); //this is C[x] in the paper
    var numButterflies = 0;
    forall w in graph.vertex(v).neighborList {
      forall x in graph.edge(w.id).neighborList {
        if graph.vertex(v).hasNeighbor(x) && x != graph.toVertex(v) {
          dist_two_mults[x.id] += 1;
        }
      }
    }
    forall x in dist_two_mults.domain {
      //combinations(dist_two_mults[x], 2) is the number of butterflies that include vertices v and w
      numButterflies += combinations(dist_two_mults[x], 2);
    }
    return numButterflies;
  }

  proc getInclusionNumCaterpillars(graph, v, e) {
    return (graph.vertex(v).neighborList.size - 1) * (graph.edge(e).neighborList.size - 1);
  }

  proc getInclusionMetamorphCoef(graph, v, e) {
    var numCaterpillars = getInclusionNumCaterpillars(graph, v, e);
    if numCaterpillars != 0 {
      return getInclusionNumButterflies(graph, v, e) / getInclusionNumCaterpillars(graph, v, e);
    }
    else {
      return 0;
    }
  }

  proc getVertexMetamorphCoefs(graph){
    var vertexMetamorphCoefs : [graph.verticesDomain] real;
    forall (v, coef) in zip(graph.getVertices(), vertexMetamorphCoefs) {
      forall e in graph.vertex(v).neighborList with (+ reduce coef) {
        coef += getInclusionMetamorphCoef(v, e);
      }
      coef = coef / graph.toVertex(v).neighborList.size;
    }
    return vertexMetamorphCoefs;
  }

  proc getEdgeMetamorphCoefs(){
    var edgeMetamorphCoefs : [graph.edgesDomain] real;
    forall (e, coef) in zip(graph.getEdges(), edgeMetamorphCoefs) {
      forall v in graph.toEdge(e).neighborList with (+ reduce coef) {
        coef += getInclusionMetamorphCoef(v, e);
      }
      coef = coef / graph.toEdge(e).neighborList.size;
    }
    return edgeMetamorphCoefs;
  }

  // N.B: May want to make a lot of these into a single larger procedure with many
  // inner procedures so we can avoid having to pass 'graph' to everything...
  iter getVerticesWithDegreeValue(graph, value : int(64)){
    for v in graph.getVertices() do if v.numNeighbors == value then yield v;
  }

  iter getVerticesWithDegreeValue(graph, value : int(64), param tag : iterKind) where tag == iterKind.standalone {
    forall v in graph.getVertices() do if v.numNeighbors == value then yield v;
  }

  iter getEdgesWithDegreeValue(graph, value : int(64)){
    for e in graph.getEdges() do if e.numNeighbors == value then yield e;
  }

  iter getEdgesWithDegreeValue(graph, value : int(64), param tag : iterKind) where tag == iterKind.standalone {
    forall e in graph.getEdges() do if e.numNeighbors == value then yield e;
  }

  proc getVertexPerDegreeMetamorphosisCoefficients(graph) {
    var vertexDegrees = graph.getVertexDegrees();
    var maxDegree = max(vertexDegrees);
    var perDegreeMetamorphCoefs : [0..maxDegree] real;
    var vertexMetamorphCoef = graph.getVertexMetamorphCoefs();

    forall (degree, metaMorphCoef) in zip(perDegreeMetamorphCoefs.domain, perDegreeMetamorphCoefs) {
      var sum = 0;
      var count = 0;
      forall v in graph.getVerticesWithDegreeValue(degree) with (+ reduce sum, + reduce count) {
        sum += vertexMetamorphCoefs[v];
        count += 1;
      }
      metaMorphCoef = sum / count;
    }
    return perDegreeMetamorphCoefs;
  }

  proc getEdgePerDegreeMetamorphosisCoefficients(graph){
    var edgeDegrees = graph.getEdgeDegrees();
    var maxDegree = max(edgeDegrees);
    var perDegreeMetamorphCoefs : [0..maxDegree] real;
    var edgeMetamorphCoef = getEdgeMetamorphCoefs();

    forall (degree, metaMorphCoef) in zip(perDegreeMetamorphCoefs.domain, perDegreeMetamorphCoefs) {
      var sum = 0;
      var count = 0;
      forall v in graph.getEdgesWithDegreeValue(degree) with (+ reduce sum, + reduce count) {
        sum += edgeMetamorphCoefs[v];
        count += 1;
      }
      metaMorphCoef = sum / count;
    }
    return perDegreeMetamorphCoefs;
  }

  proc getEdgeButterflies(graph) {
    var butterflyDom = graph.edgesDomain;
    var butterflyArr : [butterflyDom] int(64);
    // Note: If set of edges or its domain has changed this may result in errors
    // hence this is not entirely thread-safe yet...
    forall (num_butterflies, e) in zip(butterflyArr, graph.edgesDomain) {
      var dist_two_mults : [edgesDomain] int(64); //this is C[w] in the paper, which is the number of distinct distance-two paths that connect v and w
      //C[w] is equivalent to the number of edges that v and w are both connected to
      forall u in graph.edge(e).neighborList {
        forall w in graph.vertex(u.id).neighborList {
          if w.id != e {
            dist_two_mults[w.id] += 1;
          }
        }
      }
      forall w in dist_two_mults.domain {
        if dist_two_mults[w] >1 {
          //combinations(dist_two_mults[w], 2) is the number of butterflies that include edges e and w
          //num_butterflies += combinations(dist_two_mults[w], 2);
          butterflyArr[e] += combinations(dist_two_mults[w], 2);
        }
      }
    }
    return butterflyArr;

  }

  proc getVertexCaterpillars(graph) {
    var caterpillarDom = graph.verticesDomain;
    var caterpillarArr : [caterpillarDom] int(64);
    // Note: If set of vertices or its domain has changed this may result in errors
    // hence this is not entirely thread-safe yet...
    forall (num_caterpillar, v) in zip(caterpillarArr, graph.verticesDomain) {
      var dist_two_mults : [graph.verticesDomain] int(64); //this is C[w] in the paper, which is the number of distinct distance-two paths that connect v and w
      //C[w] is equivalent to the number of edges that v and w are both connected to
      forall u in graph.vertex(v).neighborList {
        forall w in graph.edge(u).neighborList {
          if w.id != v {
            dist_two_mults[w.id] += 1;
            dist_two_mults[v] += 1; //if this is added then all caterpillars including this vertex will be included in the count
          }
        }
      }

      // Hoisted this out of loop...
      const reduced = + reduce dist_two_mults;
      forall w in dist_two_mults.domain {
        if dist_two_mults[w] >1 {
          //combinations(dist_two_mults[w], 2) is the number of butterflies that include edges e and w
          //num_butterflies += combinations(dist_two_mults[w], 2);
          caterpillarArr[v] = reduced;
        }
      }
    }
    return  caterpillarArr;
  }

  proc getEdgeCaterpillars(graph) {
    var caterpillarDom = graph.edgesDomain;
    var caterpillarArr : [caterpillarDom] int(64);
    // Note: If set of edges or its domain has changed this may result in errors
    // hence this is not entirely thread-safe yet...
    forall (num_caterpillars, e) in zip(caterpillarArr, graph.edgesDomain) {
      var dist_two_mults : [graph.edgesDomain] int(64); //this is C[w] in the paper, which is the number of distinct distance-two paths that connect v and w
      //C[w] is equivalent to the number of edges that v and w are both connected to
      forall u in graph.edge(e).neighborList {
        forall w in graph.vertex(u).neighborList {
          if w.id != e {
            dist_two_mults[w.id] += 1;
            dist_two_mults[e] += 1; //if this is added then all caterpillars including this edge will be included in the count
          }
        }
      }

      // Hoisted this out of loop...
      const reduced = + reduce dist_two_mults;
      forall w in dist_two_mults.domain {
        if dist_two_mults[w] >1 {
          //combinations(dist_two_mults[w], 2) is the number of butterflies that include edges e and w
          //num_butterflies += combinations(dist_two_mults[w], 2);
          caterpillarArr[e] = reduced;
        }
      }
    }
    return caterpillarArr;

  }
}
