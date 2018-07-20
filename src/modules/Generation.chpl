module Generation {

  use IO;
  use Random;
  use CyclicDist;
  use AdjListHyperGraph;
  use Math;
  use Sort;
  use Search;

  param GenerationSeedOffset = 0xDEADBEEF;

  //Pending: Take seed as input
  //Returns index of the desired item
  inline proc getRandomElement(elements, probabilities,randValue){
    for (idx, probability) in zip(0..#probabilities.size, probabilities) {
      if probability > randValue then return elements.low + idx;
    }
    halt("Bad probability randValue: ", randValue, ", requires one between ",
         probabilities[probabilities.domain.low], " and ", probabilities[probabilities.domain.high]);
  }

  proc histogram(probabilities, numRandoms, seed = 1) {
    var indices : [1..numRandoms] int;
    var rngArr : [1..numRandoms] real;
    var newProbabilities : [1..1] real;
    if numRandoms == 0 then return indices;
    newProbabilities.push_back(probabilities);
    fillRandom(rngArr);
    const lo = newProbabilities.domain.low;
    const hi = newProbabilities.domain.high;
    const size = newProbabilities.size;

    // probabilities is binrange, rngArr is X
    forall (rng, ix) in zip(rngArr, indices) {
      var offset = 1;
      // Find a probability less than or equal to rng in log(n) time
      while (offset <= size && rng > newProbabilities[offset]) {
        offset *= 2;
      }
      
      // Find the first probability less than or equal to rng
      offset = min(offset, size);
      while offset != 0 && rng < newProbabilities[offset - 1] {
        offset -= 1;
      }
      
      // Special case - when we reach first or last element, keep them the same as they have their own bin
      // Otherwise offset by -1 again as we want to be in the correct bin (a,b)
      ix = offset - 2;
      assert(ix >= 0);
    }
    
    return indices;
  }

  proc generateErdosRenyiSMP(graph, probability, vertexDomain, edgeDomain, couponCollector = true) {
    // Rounds a real into an int
    proc _round(x : real) : int {
      return round(x) : int;
    }
    const numVertices = vertexDomain.size;
    const numEdges = edgeDomain.size;
    var newP = if couponCollector then log(1/(1-probability)) else probability;
    var inclusionsToAdd = _round(numVertices * numEdges * newP);
    writeln("Inclusions to add: ", inclusionsToAdd);
    // Perform work evenly across all tasks
    var _randStream = new RandomStream(int, GenerationSeedOffset + here.id * here.maxTaskPar);
    var randStream = new RandomStream(int, _randStream.getNext());
    forall 1..inclusionsToAdd {
      var vertex = randStream.getNext(vertexDomain.low, vertexDomain.high);
      var edge = randStream.getNext(edgeDomain.low, edgeDomain.high);
      graph.addInclusion(vertex, edge);
    }

    return graph;
  }
  
  proc generateErdosRenyiSMP(graph, probability) {
    var inclusionsToAdd = (graph.numVertices * graph.numEdges * probability) : int;
    // Perform work evenly across all tasks
    coforall tid in 0..#here.maxTaskPar {
      var perTaskInclusions = inclusionsToAdd / here.maxTaskPar + (if tid == 0 then inclusionsToAdd % here.maxTaskPar else 0);
      // Each thread gets its own random stream to avoid acquiring sync var
      var _randStream = new RandomStream(int, GenerationSeedOffset + here.id * here.maxTaskPar + tid);
      var randStream = new RandomStream(int, _randStream.getNext());
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
      sync coforall tid in 0..#here.maxTaskPar {
        // Perform work evenly across all tasks
        var perTaskInclusions = perLocaleInclusions / here.maxTaskPar + (if tid == 0 then perLocaleInclusions % here.maxTaskPar else 0);
        // Each thread gets its own random stream to avoid acquiring sync var
        var _randStream = new RandomStream(int, GenerationSeedOffset + here.id * here.maxTaskPar + tid);
        var randStream = new RandomStream(int, _randStream.getNext());
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
        var _randStream = new RandomStream(int, GenerationSeedOffset + here.id * here.maxTaskPar + tid);
        var randStream = new RandomStream(int, _randStream.getNext());
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
      var _randStream = new RandomStream(int, GenerationSeedOffset + here.id * here.maxTaskPar);
      var randStream = new RandomStream(int, _randStream.getNext());

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
      var _randStream = new RandomStream(int, GenerationSeedOffset + here.id * here.maxTaskPar + tid);
      var randStream = new RandomStream(real, _randStream.getNext());
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
    var vertexBin = histogram(vertexScan, inclusionsToAdd);
    var edgeBin = histogram(edgeScan, inclusionsToAdd);
    forall (vIdx, eIdx) in zip(vertexBin, edgeBin) {
      graph.addInclusionBuffered(verticesDomain.low + vIdx, edgesDomain.low + eIdx);
    }

    graph.flushBuffers();
    return graph;
  }

  proc generateChungLuAdjusted(graph, num_vertices, num_edges, desired_vertex_degrees, desired_edge_degrees){
    var inclusions_to_add =  + reduce desired_vertex_degrees:int;
    return generateChungLu(graph, num_vertices, num_edges, desired_vertex_degrees, desired_edge_degrees, inclusions_to_add);
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

  // Rounds a real into an int
  proc _round(x : real) : int {
      return round(x) : int;
  }

  /*
    Block Two-Level Erdos Renyi
  */
  proc generateBTER(
      vd : [?vdDom], /* Vertex Degrees */
      ed : [?edDom], /* Edge Degrees */
      vmc : [?vmcDom], /* Vertex Metamorphosis Coefficient */
      emc : [?emcDom], /* Edge Metamorphosis Coefficient */
      targetLocales = Locales
      ) {

    // Obtains the minimum value that exceeds one
    proc minimalGreaterThanOne(arr) {
      for (a, idx) in zip(arr, arr.dom) do if a > 1 then return idx;
      halt("No member found that is greater than 1...");
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

    var blockID = 1;
    var expectedDuplicates : int;
    while (idV <= numV && idE <= numE){
      var (dV, dE) = (vd[idV], ed[idE]);
      var (mV, mE) = (vmc[dV - 1], emc[dE - 1]);
      (nV, nE, rho) = computeAffinityBlocks(dV, dE, mV, mE);
      var nV_int = nV:int;
      var nE_int = nE:int;
      blockID += 1;

      // Check to ensure that blocks are only applied when it fits
      // within the range of the number of vertices and edges provided.
      // This avoids processing a most likely "wrong" value of rho as
      // mentioned by Sinan.
      if (((idV + nV_int) <= numV) && ((idE + nE_int) <= numE)) {
        var verticesDomain = graph.verticesDomain[idV..#nV_int];
        var edgesDomain = graph.edgesDomain[idE..#nE_int];
        expectedDuplicates += (round(nV_int * nE_int * log(1/(1-rho))) - round(nV_int * nE_int * rho)) : int;
        generateErdosRenyi(graph, rho, verticesDomain, edgesDomain,  couponCollector = true);  
        writeln("Block #", blockID, ", verticesDomain=", verticesDomain, ", edgesDomain=", edgesDomain, ", output=", (nV, nE, rho), ", input=", (dV, dE, mV, mE));
        idV += nV_int;
        idE += nE_int;
      } else {
        break;
      }
    }
    graph.removeDuplicates(); 
    forall (v, vDeg) in graph.forEachVertexDegree() {
      var oldDeg = vd[v.id];
      vd[v.id] = max(0, oldDeg - vDeg);
    }
    forall (e, eDeg) in graph.forEachEdgeDegree() {
      var oldDeg = ed[e.id];
      ed[e.id] = max(0, oldDeg - eDeg);
    }
    var nInclusions = _round(max(+ reduce vd, + reduce ed));
    generateChungLu(graph, graph.verticesDomain, graph.edgesDomain, vd, ed, nInclusions);

    return graph;
  }
  }

