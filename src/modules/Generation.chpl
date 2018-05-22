module Generation {

	use IO;
	use Random;
	use CyclicDist;
	use AdjListHyperGraph;
	use Math;
	use Sort;

	iter getPairs(adjList) {
		// Only iterate over smaller of vertices or edges in parallel...
		if adjList.numVertices > adjList.numEdges {
			for v in adjList.getVertices() {
				for e in adjList.getEdges() {
					yield (v,e);
				}
			}
		} else {
			for e in adjList.getEdges() {
				for v in adjList.getVertices() {
					yield (v,e);
				}
			}
		}
	}

	// Return a pair of all vertices and nodes in parallel
	iter getPairs(adjList, param tag : iterKind) where tag == iterKind.standalone {
		// Only iterate over smaller of vertices or edges in parallel...
		if adjList.numVertices > adjList.numEdges {
			forall v in adjList.getVertices() {
				for e in adjList.getEdges() {
					yield (v,e);
				}
			}
		} else {
			forall e in adjList.getEdges() {
				for v in adjList.getVertices() {
					yield (v,e);
				}
			}
		}
	}

	//Pending: Take seed as input
	//Returns index of the desired item
	proc get_random_element(elements, probabilities,randValue){
		for (idx, probability) in zip(0..#probabilities.size, probabilities) {
			if probability > randValue then return elements.low + idx;
		}
		halt("Bad probability randValue: ", randValue, ", requires one between ",
			probabilities[probabilities.domain.low], " and ", probabilities[probabilities.domain.high]);

	}

	proc fast_adjusted_erdos_renyi_hypergraph(graph, vertices_domain, edges_domain, p, targetLocales = Locales) {
		var desired_vertex_degrees: [vertices_domain] real;
  	var desired_edge_degrees: [edges_domain] real;
  	var num_vertices = vertices_domain.size;
  	var num_edges = edges_domain.size;
  	desired_vertex_degrees = num_edges * p;
		desired_edge_degrees = num_vertices * p;
  	var inclusions_to_add = (num_vertices*num_edges*log(p/(1-p))): int;
  	var new_graph = fast_hypergraph_chung_lu(graph, vertices_domain, edges_domain, desired_vertex_degrees, desired_edge_degrees, inclusions_to_add, targetLocales);
  	return new_graph;
  }


//Pending: Take seed as input
  proc erdos_renyi_hypergraph(num_vertices, num_edges, p) {
      var randStream: RandomStream(real) = new RandomStream(real, 123);
      var graph = new AdjListHyperGraph(num_vertices, num_edges);

      forall (vertex, edge) in getPairs(graph) {
        // Note: Since currently we use a lock for NodeData, parallelism is stunted
				var nextRand = randStream.getNext();
				if nextRand <= p then
					graph.add_inclusion(vertex, edge);
			}

      return graph;
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
		vd : [?vdDom] integral, /* Vertex Degrees */
		ed : [?edDom] integral, /* Edge Degrees */
		vmc : [?vmcDom] real, /* Vertex Metamorphosis Coefficient */
		emc : [?emcDom] real /* Edge Metamorphosis Coefficient */
		) {
			// Obtains the minimum value that exceeds one
			proc minimalGreaterThanOne(arr) { for a in arr do if a > 1 then return a; }

			// Computes the triple (nV, nE, rho) which are used to determine affinity blocks
			proc computeAffinityBlocks(dV, dE, mV, mE){
				var (nV, nE, rho) : 3 * real;

				//determine the nV, nE, rho
				if (mV / mE >= 1) {
					nV = dE;
					nE = if mE != 0  then round((mV / mE) * dV) else 0;
					rho = (((dV - 1) * (mE ** 2.0)) / (mV * dV - mE)) ** (1 / 4.0);
				} else {
					nE = dV;
					nV = if mV != 0 then round((mE / mV) * dE) else 0;
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
				fast_adjusted_erdos_renyi_hypergraph(graph, graph.vertices_dom, graph.edges_dom, rho);
				idV += round(nV);
				idE += round(nE);
			}

			forall (v, vDeg) in graph.forEachVertexDegree() {
	  			var oldDeg = vd[v.id+vdDom.low];
	  			vd[v.id+vdDom.low] = max(0, oldDeg - vDeg);
			}
			forall (e, eDeg) in graph.forEachEdgeDegree() {
	  			var oldDeg = ed[e.id+edDom.low];
	  			ed[e.id+edDom.low] = max(0, oldDeg - eDeg);
			}
			var nInclusions = round(max(+ reduce vd, + reduce ed));
			return fast_hypergraph_chung_lu(graph, graph.vertices_dom, graph.edges_dom, vd, ed, nInclusions);
	}
}
