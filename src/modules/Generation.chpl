module Generation {

  use IO;
  use Random;
  use CyclicDist;
  use AdjListHyperGraph;
  use Math;
  use Sort;

  //Pending: Take seed as input
  //Returns index of the desired item
  proc get_random_element(elements, probabilities,randValue){
    for (idx, probability) in zip(0..#probabilities.size, probabilities) {
      if probability > randValue then return elements.low + idx;
    }
    halt("Bad probability randValue: ", randValue, ", requires one between ",
         probabilities[probabilities.domain.low], " and ", probabilities[probabilities.domain.high]);
  }

  proc fast_simple_er(graph, probability, targetLocales = Locales){
    var inclusionsToAdd = (graph.numVertices * graph.numEdges * probability) : int;
    coforall loc in targetLocales do on loc {
        // Normalize both probabilities
        var perLocaleInclusions = (inclusionsToAdd / numLocales) + (if here.id == 0 then (inclusionsToAdd % numLocales) else 0);
        coforall tid in  1..here.maxTaskPar {
          var perTaskInclusions = perLocaleInclusions / here.maxTaskPar + (if tid == 1 then (perLocaleInclusions % here.maxTaskPar) else 0);
          var randStream = new RandomStream(int(64));
          writeln("Task ", tid, " is running ", perTaskInclusions, " inclusions.");
          for 1..perTaskInclusions {
            // A better way to get the max and min values for this random gen?
            var vertex = randStream.getNext(0, graph.numVertices - 1);
            var edge = randStream.getNext(graph._edges_dom.localSubdomain().low, graph._edges_dom.localSubdomain().high);
            //            writeln(here.id, " ", vertex, " ", edge);
            graph.add_inclusion(vertex, edge);
          }
        }
      }

    // TODO: Remove duplicate edges...
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
    var graph = new AdjListHyperGraph(vertices_domain, edges_domain);

    // Spawn a remote task on each node...
    coforall loc in targetLocales do on loc {
        var randStream: RandomStream(real) = new RandomStream(real, 123);

        // Process either vertices of edges in parallel based on relative size.
        if graph.numVertices > graph.numEdges {
          forall v in graph.verticesDomain.localSubdomain() {
            for e in graph.edgesDomain.localSubdomain() {
              if randStream.getNext() <= p {
                graph.add_inclusion(v,e);
              }
            }
          }
        } else {
          forall e in graph.edgesDomain.localSubdomain() {
            for v in graph.verticesDomain.localSubdomain() {
              if randStream.getNext() <= p {
                graph.add_inclusion(v,e);
              }
            }
          }
        }
      }

    return graph;
  }

  proc remove_duplicates(g){
    var offset = g.verticesDomain.low;
    var g2 = new AdjListHyperGraph(g.vertices.size,g.edges.size);
    forall v in g.verticesDomain.low..g.verticesDomain.high{
      var adjList : [g.edgesDomain.low .. g.edgesDomain.high] int;
      for e in g.vertices(v).neighborList{
        adjList[e.id] = 1;
      }
      for e in 0..adjList.size-1{
        if adjList[e] > 0{
          g2.add_inclusion(v,e);
        }
      }
    }

    return g2;
  }



  proc fast_hypergraph_chung_lu(graph, vertices_domain, edges_domain, desired_vertex_degrees, desired_edge_degrees, inclusions_to_add, targetLocales = Locales){
    var sum_degrees = + reduce desired_vertex_degrees:real;
    var vertex_probabilities = desired_vertex_degrees/sum_degrees: real;
    var edge_probabilities = desired_edge_degrees/sum_degrees: real;
    var vertexScan : [vertex_probabilities.domain] real = + scan vertex_probabilities;
    var edgeScan : [edge_probabilities.domain] real = + scan edge_probabilities;

    coforall loc in targetLocales do on loc {
        // If the current node has local work...
        if vertex_probabilities.localSubdomain().size != 0 {
          // Obtain localized probabilities
          var localVertexProbabilities = vertex_probabilities[vertex_probabilities.localSubdomain()];
          var localEdgeProbabilities = edge_probabilities[edge_probabilities.localSubdomain()];

          // If the entire array is 0, then we do not have any work to do...
          // N.B: We end up generating less inclusions than asked if one of
          // the probabilities are all zero while the other is not. In the future
          // we would want to actually keep track of the amount of inclusions we did
          // not generate and handle it at the end.
          var hasWork : bool;
          for (vProb, eProb) in zip(localVertexProbabilities, localEdgeProbabilities) {
            if vProb != 0 || eProb != 0 {
              hasWork = true;
              break;
            }
          }

          // There is at least one element in either probabilities array...
          if hasWork {
            // Normalize both probabilities
            localVertexProbabilities /= (+ reduce localVertexProbabilities);
            localEdgeProbabilities /= (+ reduce localEdgeProbabilities);

            // Scan both probabilities
            localVertexProbabilities = (+ scan localVertexProbabilities);
            localEdgeProbabilities = (+ scan localEdgeProbabilities);

            var perLocaleInclusions = inclusions_to_add / numLocales;
            coforall 1..here.maxTaskPar {
              var perTaskInclusions = perLocaleInclusions / here.maxTaskPar;
              var randStream = new RandomStream(real);
              for 1..perTaskInclusions {
                var vertex = get_random_element(vertices_domain.localSubdomain(), localVertexProbabilities, randStream.getNext());
                var edge = get_random_element(edges_domain.localSubdomain(), localEdgeProbabilities, randStream.getNext());
                graph.add_inclusion(vertex, edge);
              }
            }
          }
        }
      }

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

    // Ensure that all arrays are sorted (in parallel)
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
    var graph = new AdjListHyperGraph(vdDom, edDom);

    while (idV <= numV && idE <= numE){
      var (dV, dE) = (vd[idV], ed[idE]);
      var (mV, mE) = (vmc[dV], emc[dE]);
      (nV, nE, rho) = computeAffinityBlocks(dV, dE, mV, mE);
      fast_adjusted_erdos_renyi_hypergraph(graph, graph.verticesDomain, graph.edgesDomain, rho, couponCollector = true);
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
