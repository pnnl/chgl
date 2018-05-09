module Generation {
  use IO;
  use Random;
  use CyclicDist;
  use AdjListHyperGraph;
  use Math;

	//Pending: Take seed as input
	//Returns index of the desired item
	proc get_random_element(edge_domain, probabilities){
		var sum_probs = + reduce probabilities:real;
		var randStream: RandomStream(real) = new RandomStream(real);
		var r = randStream.getNext()*sum_probs: real;
		var temp_sum = 0.0: real;
		var item = -99;
		for i in probabilities.domain
		{
			temp_sum += probabilities[i];
			if r <= temp_sum
			{
				item = i;
				break;
			}
		}
		return edge_domain[item];
	}

  proc fast_adjusted_erdos_renyi_hypergraph(graph, num_vertices, num_edges, p) {
  	var desired_vertex_degrees = [0..num_vertices]: real;
  	var desired_edge_degrees = [0..num_edges]: real;
  	forall i in desired_vertex_degrees.domain{
  		desired_vertex_degrees[i] = num_edges*p;
  	}
  	forall i in desired_edge_degrees.domain{
  		desired_edge_degrees[i] = num_vertices*p;
  	}
  	var inclusions_to_add = num_vertices*num_edges*log(p/(1-p)): int;
  	graph = fast_hypergraph_chung_lu(graph, num_vertices, num_edges, desired_vertex_degrees, desired_edge_degrees, inclusions_to_add);
  	return graph;
  }

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

	//Following the pseudo code provided in the paper: Measuring and Modeling Bipartite Graphs with Community Structure
	proc fast_hypergraph_chung_lu(graph, num_vertices, num_edges, desired_vertex_degrees, desired_edge_degrees, inclusions_to_add){
		var sum_degrees = + reduce desired_vertex_degrees:int;
		var vertex_probabilities: [1..num_vertices] real;
		var edge_probabilities: [1..num_edges] real;

		forall idx in desired_vertex_degrees.domain{
			vertex_probabilities[idx] = desired_vertex_degrees[idx]/sum_degrees:real;
		}
		forall idx in desired_edge_degrees.domain{
			edge_probabilities[idx] = desired_edge_degrees[idx]/sum_degrees:real;
		}

		forall k in 1..inclusions_to_add
		{
			var vertex = get_random_element(desired_vertex_degrees, vertex_probabilities);
			var edge = get_random_element(desired_edge_degrees, edge_probabilities);
			//writeln("vertex,edge: ",vertex, edge);
			graph.add_inclusion(vertex, edge);//How to check duplicate edge??
		}
		return graph;
    }

	//proc fast_adjusted_hypergraph_chung_lu(graph, num_vertices, num_edges, desired_vertex_degrees, desired_edge_degrees){
	//	var inclusions_to_add = ?
	//	return fast_hypergraph_chung_lu(graph, num_vertices, num_edges, desired_vertex_degrees, desired_edge_degrees, inclusions_to_add);
	//}

    // proc chung_lu_naive_hypergraph(desired_vertex_degrees, desired_edge_degrees, desired_num_edges){
    //     var randStream: RandomStream(real) = new RandomStream(real);
    //     const vertex_domain = {1..num_nodes} dmapped Cyclic(startIdx=0);
    //     const edge_domain = {1..num_edges} dmapped Cyclic(startIdx=0);
    //     var graph = new AdjListHyperGraph(vertices_dom = vertex_domain, edges_dom = edge_domain);
    //     for vertex in vertex_domain do
    //         for edge in edge_domain do
    //             p = (desired_vertex_degrees[vertex]*desired_edge_degrees[edge])/(2*desired_num_edges); #this needs more work
    //             var nextRand = randStream.getNext();
    //             if nextRand <= p then
    //                 graph.add_inclusion(vertex, edge);
    //     return graph;
    // }

    // proc chung_lu_fast_hypergraph(desired_vertex_degrees, desired_edge_degrees, desired_num_edges){
    //     const vertex_domain = {1..num_nodes} dmapped Cyclic(startIdx=0);
    //     const edge_domain = {1..num_edges} dmapped Cyclic(startIdx=0);
    //     var graph = new AdjListHyperGraph(vertices_dom = vertex_domain, edges_dom = edge_domain);
    //     var vertex_probabilities: [1..num_nodes] real;
    //     forall vertex in vertex_domain do
    //         p = desired_vertex_degrees[vertex]/desired_num_edges;
    //     var edge_probabilities: [1..num_edges] real;
    //     forall edge in edge_domain do
    //         p = desired_edge_degrees[edge]/desired_num_edges
    //     for k in {1..desired_num_edges} do
    //         vertex = get_random_element(vertex_domain, vertex_probabilities);
    //         edge = get_random_element(edge_domain, edge_probabilities);
    //         graph.add_inclusion(vertex, edge);
    //     return graph;
    // }
    	proc create_input_data_lists(){
		//do you want this proc to input a file or a graph object?
	}

	proc preprocess_bter(){
		//implement this
	}

	proc compute_params_for_affinity_blocks(){
	}

	proc bter_hypergraph(input_file){
		create_input_data_lists();
		preprocess_bter();
		var i : int = 0;
		var idv: int;
		var idE: int;
		var numV: int;
		var numE: int;
		while (idv <= numV && idE <= numE){
			compute_params_for_affinity_blocks();
			if (idv > numV || idE > numE){
				break; //make sure the "break" statement is the correct syntax
			}
			else{
				//we might need to modify our E-R procedure above. Please write here how we need to call the E-R procedure.
			}
			//add the other stuff in the for loop
		}
		//add additional stuff after the for loop
	}

}
