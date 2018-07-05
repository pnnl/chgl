module Generation {

  use IO;
  use Random;
  use CyclicDist;
  use AdjListHyperGraph;
  use Math;
  use Sort;

  //Pending: Take seed as input
  //Returns index of the desired item
  inline proc getRandomElement(elements, probabilities,randValue){
    for (idx, probability) in zip(0..#probabilities.size, probabilities) {
      if probability > randValue then return elements.low + idx;
    }
    halt("Bad probability randValue: ", randValue, ", requires one between ",
         probabilities[probabilities.domain.low], " and ", probabilities[probabilities.domain.high]);
  }

  proc generateErdosRenyiSMP(graph, probability, vertexDomain, edgeDomain, couponCollector = true) {
    const numVertices = vertexDomain.size;
    const numEdges = edgeDomain.size;
    var newP = if couponCollector then log(1/(1-probability)) else probability;
    var inclusionsToAdd = (numVertices * numEdges * newP) : int;
    // Perform work evenly across all tasks
    coforall tid in 0..#here.maxTaskPar {
      var perTaskInclusions = inclusionsToAdd / here.maxTaskPar + (if tid == 0 then inclusionsToAdd % here.maxTaskPar else 0);
      // Each thread gets its own random stream to avoid acquiring sync var
      var randStream = new RandomStream(int, tid);
      for 1..perTaskInclusions {
        var vertex = randStream.getNext(vertexDomain.low, vertexDomain.high);
        var edge = randStream.getNext(edgeDomain.low, edgeDomain.high);
        graph.addInclusion(vertex, edge);
      }
    }

    return graph;
  }
  
  proc generateErdosRenyiSMP(graph, probability) {
    var inclusionsToAdd = (graph.numVertices * graph.numEdges * probability) : int;
    // Perform work evenly across all tasks
    coforall tid in 0..#here.maxTaskPar {
      var perTaskInclusions = inclusionsToAdd / here.maxTaskPar + (if tid == 0 then inclusionsToAdd % here.maxTaskPar else 0);
      // Each thread gets its own random stream to avoid acquiring sync var
      var randStream = new RandomStream(int, tid);
      for 1..perTaskInclusions {
        var vertex = randStream.getNext(0, graph.numVertices - 1);
        var edge = randStream.getNext(0, graph.numEdges - 1);
        graph.addInclusion(vertex, edge);
      }
    }

    return graph;
  }

  proc generateErdosRenyi(graph, probability, targetLocales = Locales){
    var inclusionsToAdd = (graph.numVertices * graph.numEdges * probability) : int;
    // Perform work evenly across all locales
    coforall loc in targetLocales with (in graph) do on loc {
      var perLocaleInclusions = inclusionsToAdd / numLocales + (if here.id == 0 then inclusionsToAdd % numLocales else 0);
      coforall tid in 0..#here.maxTaskPar {
        // Perform work evenly across all tasks
        var perTaskInclusions = perLocaleInclusions / here.maxTaskPar + (if tid == 0 then perLocaleInclusions % here.maxTaskPar else 0);
        // Each thread gets its own random stream to avoid acquiring sync var
        var randStream = new RandomStream(int, here.id * here.maxTaskPar + tid);
        for 1..perTaskInclusions {
          var vertex = randStream.getNext(0, graph.numVertices - 1);
          var edge = randStream.getNext(0, graph.numEdges - 1);
          graph.addInclusionBuffered(vertex, edge);
        }
      }
    }
    graph.flushBuffers();
    
    return graph;
  }

  proc generateErdosRenyiUnbuffered(graph, probability, targetLocales = Locales){
    var inclusionsToAdd = (graph.numVertices * graph.numEdges * probability) : int;
    // Perform work evenly across all locales
    coforall loc in targetLocales with (in graph) do on loc {
      var perLocaleInclusions = inclusionsToAdd / numLocales + (if here.id == 0 then inclusionsToAdd % numLocales else 0);
      coforall tid in 0..#here.maxTaskPar {
        // Perform work evenly across all tasks
        var perTaskInclusions = perLocaleInclusions / here.maxTaskPar + (if tid == 0 then perLocaleInclusions % here.maxTaskPar else 0);
        // Each thread gets its own random stream to avoid acquiring sync var
        var randStream = new RandomStream(int, here.id * here.maxTaskPar + tid);
        for 1..perTaskInclusions {
          var vertex = randStream.getNext(0, graph.numVertices - 1);
          var edge = randStream.getNext(0, graph.numEdges - 1);
          graph.addInclusion(vertex, edge);
        }
      }
    }
    
    return graph;
  }

  proc generateErdosRenyiAdjusted(graph, vertices_domain, edges_domain, p, targetLocales = Locales, couponCollector = true) {
    if p == 0 then return graph;
    if isnan(p) then halt("Error: p = NAN, vertices_domain = ", vertices_domain, ", edges_domain=", edges_domain);
    var desired_vertex_degrees: [vertices_domain] real;
    var desired_edge_degrees: [edges_domain] real;
    var num_vertices = vertices_domain.size;
    var num_edges = edges_domain.size;
    desired_vertex_degrees = num_edges * p;
    desired_edge_degrees = num_vertices * p;
    // Adjust p for coupon collector
    var adjusted_p = if couponCollector then log(1/(1-p)) else p;
    var inclusions_to_add = (num_vertices*num_edges * adjusted_p): int;
    var new_graph = generateChungLu(graph, vertices_domain, edges_domain, desired_vertex_degrees, desired_edge_degrees, inclusions_to_add, targetLocales);
    return new_graph;
  }


  //Pending: Take seed as input
  proc generateErdosRenyiNaive(graph, vertices_domain, edges_domain, p, targetLocales = Locales) {
    // Spawn a remote task on each node...
    coforall loc in targetLocales with (in graph) do on loc {
      var randStream: RandomStream(real) = new RandomStream(real, 123);

      // Process either vertices of edges in parallel based on relative size.
      if graph.numVertices > graph.numEdges {
        forall v in graph.localVerticesDomain {
          for e in graph.localEdgesDomain {
            if randStream.getNext() <= p {
              graph.addInclusion(v,e);
            }
          }
        }
      } else {
        forall e in graph.localEdgesDomain {
          for v in graph.localVerticesDomain {
            if randStream.getNext() <= p {
              graph.addInclusion(v,e);
            }
          }
        }
      }
    }
    
    return graph;
  }
  
  proc generateChungLuSMP(graph, verticesDomain, edgesDomain, desiredVertexDegrees, desiredEdgeDegrees, inclusionsToAdd) {
    const reducedVertex = + reduce desiredVertexDegrees : real;
    const reducedEdge = + reduce desiredEdgeDegrees : real;
    var vertexProbabilities = desiredVertexDegrees / reducedVertex;
    var edgeProbabilities = desiredEdgeDegrees/ reducedEdge;
    var vertexScan : [vertexProbabilities.domain] real = + scan vertexProbabilities;
    var edgeScan : [edgeProbabilities.domain] real = + scan edgeProbabilities;


    return generateChungLuPreScanSMP(graph, verticesDomain, edgesDomain, vertexScan, edgeScan, inclusionsToAdd);
  }

  proc generateChungLuPreScanSMP(graph, verticesDomain, edgesDomain, vertexScan, edgeScan, inclusionsToAdd){
    // Perform work evenly across all locales
    coforall tid in 0..#here.maxTaskPar {
      // Perform work evenly across all tasks
      var perTaskInclusions = inclusionsToAdd / here.maxTaskPar + (if tid == 0 then inclusionsToAdd % here.maxTaskPar else 0);
      var randStream = new RandomStream(real, tid);
      for 1..perTaskInclusions {
        var vertex = getRandomElement(verticesDomain, vertexScan, randStream.getNext());
        var edge = getRandomElement(edgesDomain, edgeScan, randStream.getNext());
        graph.addInclusion(vertex, edge);
      }
    }

    return graph;
  }

  proc generateChungLu(graph, verticesDomain, edgesDomain, desiredVertexDegrees, desiredEdgeDegrees, inclusionsToAdd, targetLocales = Locales) {
    if inclusionsToAdd == 0 then return graph;
    var vertexProbabilities = desiredVertexDegrees/ (+ reduce desiredVertexDegrees): real;
    var edgeProbabilities = desiredEdgeDegrees/ (+ reduce desiredEdgeDegrees): real;
    var vertexScan : [vertexProbabilities.domain] real = + scan vertexProbabilities;
    var edgeScan : [edgeProbabilities.domain] real = + scan edgeProbabilities;
     
    return generateChungLuPreScan(graph, verticesDomain, edgesDomain, vertexScan, edgeScan, inclusionsToAdd, targetLocales);
  }

  proc generateChungLuPreScan(graph, verticesDomain, edgesDomain, vertexScan, edgeScan, inclusionsToAdd, targetLocales = Locales){
    //const maxVertexScan = max reduce vertexScan;
    //const maxEdgeScan = max reduce edgeScan;
    //assert(maxVertexScan == 1.0 && maxEdgeScan == 1.0, "vertexScan max = ", maxVertexScan, ", isGood?", maxVertexScan == 1.0, ",  edgeScan max = ", maxEdgeScan, ", isGood?", maxEdgeScan == 1.0);
    // Perform work evenly across all locales
    coforall loc in targetLocales with (in graph) do on loc {
      var perLocaleInclusions = inclusionsToAdd / numLocales + (if here.id == 0 then inclusionsToAdd % numLocales else 0);
      var localVertexScan = vertexScan;
      var localEdgeScan = edgeScan;
      coforall tid in 0..#here.maxTaskPar {
        // Perform work evenly across all tasks
        var perTaskInclusions = perLocaleInclusions / here.maxTaskPar + (if tid == 0 then perLocaleInclusions % here.maxTaskPar else 0);
        // Each thread gets its own random stream to avoid acquiring sync var
        // Note: This is needed due to issues with qthreads
        var randStream = new RandomStream(real, here.id * here.maxTaskPar + tid);
        for 1..perTaskInclusions {
          var vertex = getRandomElement(verticesDomain, localVertexScan, randStream.getNext());
          var edge = getRandomElement(edgesDomain, localEdgeScan, randStream.getNext());
          graph.addInclusionBuffered(vertex, edge);
        }
      }
    }

    graph.flushBuffers();
    // TODO: Remove duplicate edges...
    return graph;
  }

  proc generateChungLuAdjusted(graph, num_vertices, num_edges, desired_vertex_degrees, desired_edge_degrees){
    var inclusions_to_add =  + reduce desired_vertex_degrees:int;
    return generateChungLu(graph, num_vertices, num_edges, desired_vertex_degrees, desired_edge_degrees, inclusions_to_add);
  }

  proc generateBTER(
      vd : [?vdDom], /* Vertex Degrees */
      ed : [?edDom], /* Edge Degrees */
      vmc : [?vmcDom], /* Vertex Metamorphosis Coefficient */
      emc : [?emcDom] /* Edge Metamorphosis Coefficient */
      ) {
    // Rounds a real into an int
    proc _round(x : real) : int {
      return round(x) : int;
    }

    // Obtains the minimum value that exceeds one
    proc minimalGreaterThanOne(arr) {
      for (a, idx) in zip(arr, arr.dom) do if a > 1 then return idx;
      halt("No member found that is greater than 1...");
    }

    // Computes the triple (nV, nE, rho) which are used to determine affinity blocks
    proc computeAffinityBlocks(dV, dE, mV, mE){
      var (nV, nE, rho) : 3 * real;

      //determine the nV, nE, rho
      if (mV / mE >= 1) {
        nV = dE;
        nE = (mV / mE) * dV;
        rho = (((dV - 1) * (mE ** 2.0)) / (mV * dV - mE)) ** (1 / 4.0);
      } else {
        nE = dV;
        nV = (mE / mV) * dE;
        rho = (((dE - 1) * (mV ** 2.0))/(mE * dE - mV)) ** (1 / 4.0);
      }

      assert(!isnan(rho), (dV, dE, mV, mE), "->", (nV, nE, rho));

      return (_round(nV), _round(nE), rho);
    }

    // Check if data begins at index 0...
    assert(vdDom.low == 0 && edDom.low == 0 && vmcDom.low == 0 && emcDom.low == 0);

    cobegin {
      sort(vd);
      sort(ed);
    }

    var (nV, nE, rho) : 3 * real;
    var (idV, idE, numV, numE) = (
        minimalGreaterThanOne(vd),
        minimalGreaterThanOne(ed),
        vdDom.size,
        edDom.size
        );
    var graph = new AdjListHyperGraph(vdDom.size, edDom.size);

    while (idV <= numV && idE <= numE){
      var (dV, dE) = (vd[idV], ed[idE]);
      var (mV, mE) = (vmc[dV - 1], emc[dE - 1]);
      (nV, nE, rho) = computeAffinityBlocks(dV, dE, mV, mE);
      var nV_int = nV:int;
      var nE_int = nE:int;
      var verticesDomain = graph.verticesDomain[idV..#nV_int];
      var edgesDomain = graph.edgesDomain[idE..#nE_int];
      generateErdosRenyiSMP(graph, rho, verticesDomain, edgesDomain, couponCollector = false);
      idV += nV_int;
      idE += nE_int;
    }

    writeln("Finished computing affinity blocks");

    forall (v, vDeg) in graph.forEachVertexDegree() {
      var oldDeg = vd[v.id];
      vd[v.id] = max(0, oldDeg - vDeg);
    }
    forall (e, eDeg) in graph.forEachEdgeDegree() {
      var oldDeg = ed[e.id];
      ed[e.id] = max(0, oldDeg - eDeg);
    }
    var nInclusions = _round(max(+ reduce vd, + reduce ed));
    generateChungLuSMP(graph, graph.verticesDomain, graph.edgesDomain, vd, ed, nInclusions);
    
    return graph;
  }
}
