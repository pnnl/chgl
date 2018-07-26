module Butterfly {
  use AdjListHyperGraph;
  
  /* Calculates the maximum number of inclusions that the AdjListHyperGraph object can contain without duplicates
  
    :returns: an integer representing the number of possible combinations
  */
  
  proc combinations(_n : integral, _k : integral) {
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
    
    /* Checks if the given vertex and edge are neighbors
    
    :arg v: ID of vertex to check
    :type v: int(64)

    :arg e: ID of edge to check
    :type e: int(64)

    :returns: True if the vertex and edge are neighbors or false if vertex and edge are not neighbors
    :rtype: boolean
    */
  proc AdjListHyperGraphImpl.vertexHasNeighbor(v, e){
    return getVertex(toVertex(v)).hasNeighbor(toEdge(e));
  }
  
    /* Counts the number of 4-cycles for each vertex and stores that number as an int(64) in an array under the ID of that vertex
    
    :returns: An array of range 0..N where N is the highest vertex ID int the AdjListHyperGraph object
    :rtype: array of int(64)
  
    */
  proc AdjListHyperGraphImpl.getVertexButterflies() {
    var butterfliesDom = verticesDomain;
    var butterflies : [butterfliesDom] atomic int(64);

    // Look for the pattern (v -> u -> w)
    forall v in getVertices() {
      // A two-hop neighbor of v would be w iff (v -> u -> w)
      var twoHopNeighbors : [verticesDomain] atomic int(64);
      forall u in getNeighbors(v) {
        forall w in getNeighbors(u) {
          if w.id != v.id {
            twoHopNeighbors[w.id].fetchAdd(1);
          }
        }
      }

      // Sum up all two-hop neighbors
      forall thn in twoHopNeighbors {
        if thn.read() > 0 {
          butterflies[v.id].fetchAdd(combinations(thn.read(), 2));
        }
      }
    }

    proc stripAtomic(x) return x.read();
    return stripAtomic(butterflies);
  }

  /* Yields all vertices that share a neighboring edge with this vertex
  
  :arg v: ID of the target vertex
  :type v: int(64)
  
  :yields: All vertices that share at least one neighboring edge with this vertex
  :ytype: array of int(64)
  */
  iter AdjListHyperGraphImpl.getAdjacentVertices(v) {
    for e in getVertex(v).neighborList do for w in getEdge(e).neighborList do yield w;
  }
  
  /* Yields all vertices that share a neighboring edge with this vertex
  
  :arg v: ID of the target vertex
  :type v: int(64)
  
  :yields: All vertices that share at least one neighboring edge with this vertex
  :ytype: array of int(64)
  */
  iter AdjListHyperGraphImpl.getAdjacentVertices(v, param tag) where tag == iterKind.standalone {   
    forall e in getVertex(v).neighborList do forall w in getEdge(e).neighborList do yield w; 
  }
  
  // Inefficient!
  /* Checks if two vertices share a common neighboring edge
  
  :arg v: first vertex to compare neighborlists
  :type v: int(64)
  
  :arg w: second vertex to compare neighborlists
  :type w: int(64)
  
  :returns: boolean value indicating the truth of the two input vertices sharing an edge neighbor
  :rtype: boolean
  */
  proc AdjListHyperGraphImpl.areAdjacentVertices(v, w) {
    for e in getVertex(v).neighborList {
      for ee in getVertex(w).neighborList {
        if e == ee then return true;
      }
    }
    return false;
  }

  /* Calculates the number of 4-cycles that contain the inclusion defined by the given vertex and edge
  
  :arg v: the vertex contained in the inclusion to be tested
  :type v: vDescType
  
  :arg e: the edge contained in the inclusion to be tested
  :type e: eDescType
  
  :returns: the number of 4 cylces containing the given inclusion
  :rtype: int(64)
  */
  proc AdjListHyperGraphImpl.getInclusionNumButterflies(v, e){
    var twoHopNeighbors : [verticesDomain] atomic int(64); //this is C[x] in the paper
    
    forall w in getNeighbors(v) {
      if w.id != e.id then forall x in getNeighbors(w) {
        if getVertex(x).hasNeighbor(e) && x.id != v.id {
          twoHopNeighbors[x.id].fetchAdd(1);
        }
      }
    }

    var numButterflies : int;
    forall thn in twoHopNeighbors with (+ reduce numButterflies) {
      //combinations(dist_two_mults[x], 2) is the number of butterflies that include vertices v and w
      numButterflies += thn.read();
    }
    return numButterflies;
  }

  /* Calculates the number of 3 cycles that contains the inclusion defined by the given vertex and edge
  
  :arg v: the vertex contained within the inclusion to be tested
  :type v: vDescType
  
  :arg e: the edge contained within the inclusion to be tested
  :type e: eDescType
  
  :returns: the number of 3 cycles containing the given inclusion
  :rtype: int(64)
  */
  proc AdjListHyperGraphImpl.getInclusionNumCaterpillars(v, e) {
    return (numNeighbors(v) - 1) * (numNeighbors(e) - 1);
  }

  /* Calculates the metamorphosis coefficient of the inclusion defined by the given vertex and edge
  
  :arg v: the vertex contained within the inclusion to be tested
  :type v: vDescType
  
  :arg e: the edge contained within the inclusion to be tested
  :type e: eDescType
  
  :returns: the metamorphosis coefficient of the tested inclusion
  :rtype: real(64)
  */
  proc AdjListHyperGraphImpl.getInclusionMetamorphCoef(v, e) {
    const numCaterpillars : real = getInclusionNumCaterpillars(v, e);
    if numCaterpillars != 0 {
      const numButterflies : real = getInclusionNumButterflies(v, e);
      return numButterflies / numCaterpillars;
    } else return 0;
  }

  /* Calcuates the metamorphosis coefficient for every vertex in the AdjListHyperGraph object
  
  :returns: an array of metamorphosis coefficients where the index of each value is the ID of the associated vertex
  :rtype: real
  */
  proc AdjListHyperGraphImpl.getVertexMetamorphCoefs(){
    var vertexMetamorphCoefs : [verticesDomain] real;
    // TODO: Need leader-follower iterators to make this forall
    for (v, coef) in zip(getVertices(), vertexMetamorphCoefs) {
      forall e in getNeighbors(v) with (+ reduce coef) {
        coef += getInclusionMetamorphCoef(v, e);
      }
      
      // N.B: Do not check if numNeighbors is 0 here.
      coef /= numNeighbors(v);
    }

    return vertexMetamorphCoefs;
  }

  /* Calcuates the metamorphosis coefficient for every edge in the AdjListHyperGraph object
  
  :returns: an array of metamorphosis coefficients where the index of each value is the ID of the associated edge
  :rtype: real
  */
  proc AdjListHyperGraphImpl.getEdgeMetamorphCoefs(){
    var edgeMetamorphCoefs : [edgesDomain] real;
    // TODO: Need leader-follower iterators to make this forall
    for (e, coef) in zip(getEdges(), edgeMetamorphCoefs) {
      forall v in getNeighbors(e) with (+ reduce coef) {
        coef += getInclusionMetamorphCoef(v, e);
      }

      // N.B: Do not check if numNeighbors is 0 here.
      coef /= numNeighbors(e);
    }
    return edgeMetamorphCoefs;
  }

  /* Fetches all vertices that have the degree queried

    :arg value: The desired degree
    :type value: any numeric type that can be cast as int(64)

    :yields: Vertices with desired degree
    :ytype: vDescType
  */
  iter AdjListHyperGraphImpl.verticesWithDegree(value : int(64)){
    for v in getVertices() do if numNeighbors(v) == value then yield v;
  }
  /* Fetches all vertices that have the degree queried

    :arg value: The desired degree
    :type value: any numeric type that can be cast as int(64)

    :yields: Vertices with the desired degree
    :ytype: vDescType
  */
  iter AdjListHyperGraphImpl.verticesWithDegree(value : int(64), param tag : iterKind) where tag == iterKind.standalone {
    forall v in getVertices() do if numNeighbors(v) == value then yield v;
  }
  
  /* Fetches all edges that have the degree queried
    
  :arg value: The desired degree
  :type value: any numeric type that can be cast as int(64)

  :yields: Edges with the desired degree
  :ytype: eDescType
  */
  iter AdjListHyperGraphImpl.edgesWithDegree(value : int(64)){
    for e in getEdges() do if numNeighbors(e) == value then yield e;
  }

  /* Fetches all edges that have the degree queried
    
  :arg value: The desired degree
  :type value: any numeric type that can be cast as int(64)

  :yields: Edges with the desired degree
  :ytype: eDescType
  */
  iter AdjListHyperGraphImpl.edgesWithDegree(value : int(64), param tag : iterKind) where tag == iterKind.standalone {
    forall e in getEdges() do if numNeighbors(e) == value then yield e;
  }

  /* Calcuates the per degree metamorphosis coefficient for the vertices in the AdjListHyperGraph object
  
  :returns: a list of range 1..n where n is the value of the highest existing degree of all vertices in the AdjListHyperGraph object
  :rtype: array of int(64)
  */
  proc AdjListHyperGraphImpl.getVertexPerDegreeMetamorphosisCoefficients() {
    var vertexDegrees = getVertexDegrees();
    var maxDegree = max reduce vertexDegrees;
    var perDegreeMetamorphCoefs : [0..maxDegree] real;
    var vertexMetamorphCoefs = getVertexMetamorphCoefs();

    forall (degree, coef) in zip(perDegreeMetamorphCoefs.domain, perDegreeMetamorphCoefs) {
      var sum : real;
      var count = 0;
      forall v in verticesWithDegree(degree) with (+ reduce sum, + reduce count) {
        sum += vertexMetamorphCoefs[v.id];
        count += 1;
      }
      // N.B: Do not check if count is 0 here.
      coef = sum / count;
    }
    return perDegreeMetamorphCoefs;
  }

  /* Calcuates the per degree metamorphosis coefficient for the edges in the AdjListHyperGraph object
  
  :returns: a list of range 1..n where n is the value of the highest existing degree of all edges in the AdjListHyperGraph object
  :rtype: array of int(64)
  */
  proc AdjListHyperGraphImpl.getEdgePerDegreeMetamorphosisCoefficients(){
    var edgeDegrees = getEdgeDegrees();
    var maxDegree = max reduce edgeDegrees;
    var perDegreeMetamorphCoefs : [0..maxDegree] real;
    var edgeMetamorphCoefs = getEdgeMetamorphCoefs();

    forall (degree, coef) in zip(perDegreeMetamorphCoefs.domain, perDegreeMetamorphCoefs) {
      var sum : real;
      var count = 0;
      forall v in edgesWithDegree(degree) with (+ reduce sum, + reduce count) {
        sum += edgeMetamorphCoefs[v.id];
        count += 1;
      }
      if count != 0 then coef = sum / count;
    }
    return perDegreeMetamorphCoefs;
  }
  
  /* Counts the number of 4-cycles for each edge and stores that number as an int(64) in an array under the ID of that edge
  
  :returns: An array of range 0..N where N is the highest edge ID int the AdjListHyperGraph object
  :rtype: array of int(64)
  */
  proc AdjListHyperGraphImpl.getEdgeButterflies() {
    var butterflies : [edgesDomain] atomic int(64);
    
    // Look for pattern (e -> u -> w)
    forall e in getEdges() {
      var twoHopNeighbors : [edgesDomain] atomic int(64);
      forall u in getNeighbors(e) {
        forall w in getNeighbors(u) {    
          if w.id != e.id {
            twoHopNeighbors[w.id].fetchAdd(1);
          }
        }
      }

      forall thn in twoHopNeighbors {
        if thn.read() > 1 {
          //combinations(dist_two_mults[w], 2) is the number of butterflies that include edges e and w
          //num_butterflies += combinations(dist_two_mults[w], 2);
          butterflies[e.id].fetchAdd(combinations(thn.read(), 2));
        }
      }
    }
    
    proc stripAtomics(x) return x.read();
    return stripAtomics(butterflies);
  }

  /* Calcuates the number of 3-cycles that include each vertex
  
  :returns: An array of range 0..n where n is the highest ID of all vertices in the AdjListHyperGraph object
  :rtype: array of int(64)
  */
  proc AdjListHyperGraphImpl.getVertexCaterpillars() {
    var caterpillarsDomain = verticesDomain;
    var caterpillars : [caterpillarsDomain] int(64);
    forall v in getVertices() {
      var twoHopNeighbors : [verticesDomain] atomic int(64); //this is C[w] in the paper, which is the number of distinct distance-two paths that connect v and w
      //C[w] is equivalent to the number of edges that v and w are both connected to
      forall u in getNeighbors(v) {
        forall w in getNeighbors(u) {
          if w.id != v.id {
            twoHopNeighbors[w.id].fetchAdd(1);
            twoHopNeighbors[v.id].fetchAdd(1); //if this is added then all caterpillars including this vertex will be included in the count
          }
        }
      }

      // Hoisted this out of loop...
      var reduced : int;
      forall thn in twoHopNeighbors with (+ reduce reduced) do reduced += thn.read();
      forall thn in twoHopNeighbors {
        if thn.read() > 1 {
          //combinations(dist_two_mults[w], 2) is the number of butterflies that include edges e and w
          //num_butterflies += combinations(dist_two_mults[w], 2);
          caterpillars[v.id] = reduced;
        }
      }
    }
    return  caterpillars;
  }

  /* Calcuates the number of 3-cycles that include each edge
  
  :returns: An array of range 0..n where n is the highest ID of all edges in the AdjListHyperGraph object
  :rtype: array of int(64)
  */
  proc AdjListHyperGraphImpl.getEdgeCaterpillars() {
    var caterpillars : [edgesDomain] int(64);
    
    forall e in getEdges() {
      var twoHopNeighbors : [edgesDomain] atomic int(64); 
      forall u in getNeighbors(e) {
        forall w in getNeighbors(u) {
          if w.id != e.id {
            twoHopNeighbors[w.id].fetchAdd(1);
            twoHopNeighbors[e.id].fetchAdd(1); //if this is added then all caterpillars including this edge will be included in the count
          }
        }
      }

      // Hoisted this out of loop...
      var reduced : int;
      forall thn in twoHopNeighbors with (+ reduce reduced) do reduced += thn.read();
      forall thn in twoHopNeighbors {
        if thn.read() >1 {
          //combinations(dist_two_mults[w], 2) is the number of butterflies that include edges e and w
          //num_butterflies += combinations(dist_two_mults[w], 2);
          caterpillars[e.id] = reduced;
        }
      }
    }
    return caterpillars;

  }
}