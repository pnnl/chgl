module Butterfly {
  use AdjListHyperGraph;

  proc combinations(_n, _k) {
    if _k < 0 || _k > _n then return 0;
    if _k == 0 || _k == _n then return 1;
    
    var res = 1;
    var n = _n;
    var k = min(_k, _n - _k);

    // Calculate value of [n * (n-1) *---* (n-k+1)] / [k * (k-1) *----* 1]
    for i in 0..#k {
      res *= (n - i);
      res /= (i + 1);
    }

    return res;
  }

  proc AdjListHyperGraphImpl.vertexHasNeighbor(v, e){
    return vertex(toVertex(v)).hasNeighbor(toEdge(e));
  }

  proc AdjListHyperGraphImpl.getVertexButterflies() {
    var butterflyDom = verticesDomain;
    var butterflyArr : [butterflyDom] int(64);
    // Note: If set of vertices or its domain has changed this may result in errors
    // hence this is not entirely thread-safe yet...
    forall (num_butterflies, v) in zip(butterflyArr, verticesDomain) {
      var dist_two_mults : [verticesDomain] int(64); //this is C[w] in the paper, which is the number of distinct distance-two paths that connect v and w
      //C[w] is equivalent to the number of edges that v and w are both connected to
      forall u in vertex(v).neighborList {
        forall w in edge(u).neighborList {
          if w.id != v {
            dist_two_mults[w.id] += 1;
          }
        }
      }
      forall w in dist_two_mults {
        if dist_two_mults[w] > 0 {
          //combinations(dist_two_mults[w], 2) is the number of butterflies that include vertices v and w
          butterflyArr[v] += combinations(dist_two_mults[w], 2);
        }
      }
    }
    return butterflyArr;
  }

  iter AdjListHyperGraphImpl.getAdjacentVertices(v) {
    for e in vertex(v).neighborList do for w in edge(e).neighborList do yield w;
  }

  iter AdjListHyperGraphImpl.getAdjacentVertices(v, param tag) where tag == iterKind.standalone {   
    forall e in vertex(v).neighborList do forall w in edge(e).neighborList do yield w; 
  }
  
  // Inefficient!
  proc AdjListHyperGraphImpl.areAdjacentVertices(v, w) {
    for e in vertex(v).neighborList {
      for ee in vertex(w).neighborList {
        if e == ee then return true;
      }
    }
    return false;
  }

  proc AdjListHyperGraphImpl.getInclusionNumButterflies(v, e){
    var dist_two_mults : [verticesDomain] int(64); //this is C[x] in the paper
    var numButterflies = 0;
    forall w in vertex(v).neighborList {
      if w.id != toEdge(e).id then forall x in edge(w).neighborList {
        if vertex(x).hasNeighbor(toEdge(e)) && x.id != toVertex(v).id {
          dist_two_mults[x.id] += 1;
        }
      }
    }
    forall x in dist_two_mults with (+ reduce numButterflies) {
      //combinations(dist_two_mults[x], 2) is the number of butterflies that include vertices v and w
      numButterflies += combinations(x, 2);
    }
    return (+ reduce dist_two_mults);
  }

  proc main() {
    var graph = new AdjListHyperGraphImpl(2,2);
    for (i,j) in {0..1, 0..1} do graph.addInclusion(i,j);
    for v in graph.getVertices() do writeln("degree(", v, ") = ", graph.vertex(v).numNeighbors);
    writeln(graph.getInclusionNumButterflies(graph.toVertex(0), graph.toEdge(1)));
  }

  proc AdjListHyperGraphImpl.getInclusionNumCaterpillars(v, e) {
    return (vertex(v).neighborList.size - 1) * (edge(e).neighborList.size - 1);
  }

  proc AdjListHyperGraphImpl.getInclusionMetamorphCoef(v, e) {
    const numCaterpillars = getInclusionNumCaterpillars(v, e);
    if numCaterpillars != 0 {
      const numButterflies = getInclusionNumButterflies(v, e);
      return numButterflies / numCaterpillars;
    }
    else {
      return 0;
    }
  }

  proc AdjListHyperGraphImpl.getVertexMetamorphCoefs(){
    var vertexMetamorphCoefs : [verticesDomain] real;
    forall (v, coef) in zip(verticesDomain, vertexMetamorphCoefs) {
      forall e in vertex(v).neighborList with (+ reduce coef) {
        const meta = getInclusionMetamorphCoef(v, e);
        // if meta > 1.0 then halt("vertex ", toVertex(v).id, " and edge ", toEdge(e).id, " have a meta = ", meta);
        coef += meta;
      }
      const sz = vertex(v).neighborList.size;
      if sz != 0 then coef /= sz;
    }
    return vertexMetamorphCoefs;
  }

  proc AdjListHyperGraphImpl.getEdgeMetamorphCoefs(){
    var edgeMetamorphCoefs : [edgesDomain] real;
    forall (e, coef) in zip(getEdges(), edgeMetamorphCoefs) {
      forall v in toEdge(e).neighborList with (+ reduce coef) {
        coef += getInclusionMetamorphCoef(v, e);
      }
      const sz = edge(e).neighborList.size;
      if sz != 0 then coef /= sz;
    }
    return edgeMetamorphCoefs;
  }

  // N.B: May want to make a lot of these into a single larger procedure with many
  // inner procedures so we can avoid having to pass '' to everything...
  iter AdjListHyperGraphImpl.getVerticesWithDegreeValue(value : int(64)){
    for v in getVertices() do if vertex(v).numNeighbors == value then yield v;
  }

  iter AdjListHyperGraphImpl.getVerticesWithDegreeValue(value : int(64), param tag : iterKind) where tag == iterKind.standalone {
    forall v in getVertices() do if vertex(v).numNeighbors == value then yield v;
  }

  iter AdjListHyperGraphImpl.getEdgesWithDegreeValue(value : int(64)){
    for e in getEdges() do if edge(e).numNeighbors == value then yield e;
  }

  iter AdjListHyperGraphImpl.getEdgesWithDegreeValue(value : int(64), param tag : iterKind) where tag == iterKind.standalone {
    forall e in getEdges() do if edge(e).numNeighbors == value then yield e;
  }

  proc AdjListHyperGraphImpl.getVertexPerDegreeMetamorphosisCoefficients() {
    var vertexDegrees = getVertexDegrees();
    var maxDegree = max reduce vertexDegrees;
    var perDegreeMetamorphCoefs : [0..maxDegree] real;
    var vertexMetamorphCoefs = getVertexMetamorphCoefs();

    forall (degree, metaMorphCoef) in zip(perDegreeMetamorphCoefs.domain, perDegreeMetamorphCoefs) {
      var sum : real;
      var count = 0;
      forall v in getVerticesWithDegreeValue(degree) with (+ reduce sum, + reduce count) {
        sum += vertexMetamorphCoefs[v];
        count += 1;
      }
      if count != 0 then metaMorphCoef = sum / count;
    }
    return perDegreeMetamorphCoefs;
  }

  proc AdjListHyperGraphImpl.getEdgePerDegreeMetamorphosisCoefficients(){
    var edgeDegrees = getEdgeDegrees();
    var maxDegree = max(edgeDegrees);
    var perDegreeMetamorphCoefs : [0..maxDegree] real;
    var edgeMetamorphCoef = getEdgeMetamorphCoefs();

    forall (degree, metaMorphCoef) in zip(perDegreeMetamorphCoefs.domain, perDegreeMetamorphCoefs) {
      var sum = 0;
      var count = 0;
      forall v in getEdgesWithDegreeValue(degree) with (+ reduce sum, + reduce count) {
        sum += edgeMetamorphCoefs[v];
        count += 1;
      }
      if count != 0 then metaMorphCoef = sum / count;
    }
    return perDegreeMetamorphCoefs;
  }

  proc AdjListHyperGraphImpl.getEdgeButterflies() {
    var butterflyDom = edgesDomain;
    var butterflyArr : [butterflyDom] int(64);
    // Note: If set of edges or its domain has changed this may result in errors
    // hence this is not entirely thread-safe yet...
    forall (num_butterflies, e) in zip(butterflyArr, edgesDomain) {
      var dist_two_mults : [edgesDomain] int(64); //this is C[w] in the paper, which is the number of distinct distance-two paths that connect v and w
      //C[w] is equivalent to the number of edges that v and w are both connected to
      forall u in edge(e).neighborList {
        forall w in vertex(u.id).neighborList {
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

  proc AdjListHyperGraphImpl.getVertexCaterpillars() {
    var caterpillarDom = verticesDomain;
    var caterpillarArr : [caterpillarDom] int(64);
    // Note: If set of vertices or its domain has changed this may result in errors
    // hence this is not entirely thread-safe yet...
    forall (num_caterpillar, v) in zip(caterpillarArr, verticesDomain) {
      var dist_two_mults : [verticesDomain] int(64); //this is C[w] in the paper, which is the number of distinct distance-two paths that connect v and w
      //C[w] is equivalent to the number of edges that v and w are both connected to
      forall u in vertex(v).neighborList {
        forall w in edge(u).neighborList {
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

  proc AdjListHyperGraphImpl.getEdgeCaterpillars() {
    var caterpillarDom = edgesDomain;
    var caterpillarArr : [caterpillarDom] int(64);
    // Note: If set of edges or its domain has changed this may result in errors
    // hence this is not entirely thread-safe yet...
    forall (num_caterpillars, e) in zip(caterpillarArr, edgesDomain) {
      var dist_two_mults : [edgesDomain] int(64); //this is C[w] in the paper, which is the number of distinct distance-two paths that connect v and w
      //C[w] is equivalent to the number of edges that v and w are both connected to
      forall u in edge(e).neighborList {
        forall w in vertex(u).neighborList {
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
