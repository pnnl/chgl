module Generation {

  use IO;
  use Random;
  use CyclicDist;
  use AdjListHyperGraph;
  use Math;
  use Sort;

  //Pending: Take seed as input
  //Returns index of the desired item
  inline proc get_random_element(elements, probabilities,randValue){
    for (idx, probability) in zip(0..#probabilities.size, probabilities) {
      if probability > randValue then return elements.low + idx;
    }
    halt("Bad probability randValue: ", randValue, ", requires one between ",
         probabilities[probabilities.domain.low], " and ", probabilities[probabilities.domain.high]);
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

  proc fast_simple_er(graph, probability, targetLocales = Locales){
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

  proc fast_adjusted_erdos_renyi_hypergraph(graph, vertices_domain, edges_domain, p, targetLocales = Locales, couponCollector = false) {
    var desired_vertex_degrees: [vertices_domain] real;
    var desired_edge_degrees: [edges_domain] real;
    var num_vertices = vertices_domain.size;
    var num_edges = edges_domain.size;
    desired_vertex_degrees = num_edges * p;
    desired_edge_degrees = num_vertices * p;
    // Adjust p for coupon collector
    var adjusted_p = if couponCollector then log(1/(1-p)) else p;
    var inclusions_to_add = (num_vertices*num_edges * adjusted_p): int;
    var new_graph = fast_hypergraph_chung_lu(graph, vertices_domain, edges_domain, desired_vertex_degrees, desired_edge_degrees, inclusions_to_add, targetLocales);
    return new_graph;
  }


  //Pending: Take seed as input
  proc erdos_renyi_hypergraph(graph, vertices_domain, edges_domain, p, targetLocales = Locales) {
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

  proc fast_hypergraph_chung_lu(graph, verticesDomain, edgesDomain, desiredVertexDegrees, desiredEdgeDegrees, inclusionsToAdd, targetLocales = Locales){
    var vertexProbabilities = desiredVertexDegrees/ (+ reduce desiredVertexDegrees): real;
    var edgeProbabilities = desiredEdgeDegrees/ (+ reduce desiredEdgeDegrees): real;
    var vertexScan : [vertexProbabilities.domain] real = + scan vertexProbabilities;
    var edgeScan : [edgeProbabilities.domain] real = + scan edgeProbabilities;

    // Perform work evenly across all locales
    coforall loc in targetLocales with (in graph) do on loc {
      var perLocaleInclusions = inclusionsToAdd / numLocales + (if here.id == 0 then inclusionsToAdd % numLocales else 0);
      coforall tid in 0..#here.maxTaskPar {
        // Perform work evenly across all tasks
        var perTaskInclusions = perLocaleInclusions / here.maxTaskPar + (if tid == 0 then perLocaleInclusions % here.maxTaskPar else 0);
        // Each thread gets its own random stream to avoid acquiring sync var
        // Note: This is needed due to issues with qthreads
        var randStream = new RandomStream(real, here.id * here.maxTaskPar + tid);
        for 1..perTaskInclusions {
          var vertex = get_random_element(verticesDomain, vertexScan, randStream.getNext());
          var edge = get_random_element(edgesDomain, edgeScan, randStream.getNext());
          graph.addInclusionBuffered(vertex, edge);
        }
      }
    }

    graph.flushBuffers();
    // TODO: Remove duplicate edges...
    return graph;
  }

  proc fast_adjusted_hypergraph_chung_lu(graph, num_vertices, num_edges, desired_vertex_degrees, desired_edge_degrees){
    var inclusions_to_add =  + reduce desired_vertex_degrees:int;
    return fast_hypergraph_chung_lu(graph, num_vertices, num_edges, desired_vertex_degrees, desired_edge_degrees, inclusions_to_add);
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
      for a in arr do if a > 1 then return a;
      halt("No member found that is greater than 1...");
    }

    // Computes the triple (nV, nE, rho) which are used to determine affinity blocks
    proc computeAffinityBlocks(dV, dE, mV, mE){
      var (nV, nE, rho) : 3 * real;

      //determine the nV, nE, rho
      if (mV / mE >= 1) {
        nV = dE;
        nE = if mE != 0  then _round((mV / mE) * dV) else 0;
        rho = (((dV - 1) * (mE ** 2.0)) / (mV * dV - mE)) ** (1 / 4.0);
      } else {
        nE = dV;
        nV = if mV != 0 then _round((mE / mV) * dE) else 0;
        rho = (((dE - 1) * (mV ** 2.0))/(mE * dE - mV)) ** (1 / 4.0);
      }

      return (nV, nE, rho);
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
      var (mV, mE) = (vmc[dV], emc[dE]);
      (nV, nE, rho) = computeAffinityBlocks(dV, dE, mV, mE);
      var nV_int = nV:int;
      var nE_int = nE:int;
      var verticesDomain = graph.verticesDomain[idV..idV + nV_int];
      var edgesDomain = graph.edgesDomain[idE..idE + nE_int];
      fast_adjusted_erdos_renyi_hypergraph(graph, verticesDomain, edgesDomain, rho, couponCollector = true);
      idV += _round(nV);
      idE += _round(nE);
    }

    forall (v, vDeg) in graph.forEachVertexDegree() {
      var oldDeg = vd[v.id];
      vd[v.id] = max(0, oldDeg - vDeg);
    }
    forall (e, eDeg) in graph.forEachEdgeDegree() {
      var oldDeg = ed[e.id];
      ed[e.id] = max(0, oldDeg - eDeg);
    }
    var nInclusions = _round(max(+ reduce vd, + reduce ed));
    return fast_hypergraph_chung_lu(graph, graph.verticesDomain, graph.edgesDomain, vd, ed, nInclusions);
  }
}
