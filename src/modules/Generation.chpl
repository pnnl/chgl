module Generation {
  use IO;
  use Random;
  use CyclicDist;
  use AdjListHyperGraph;
  use Math;

	//Pending: Take seed as input
	//Returns index of the desired item
	proc get_random_element(elements, probabilities){
		var sum_probs = + reduce probabilities:real;
		var randStream: RandomStream(real) = new RandomStream(real);
		var r = randStream.getNext()*sum_probs: real;
		var temp_sum = 0.0: real;
		var the_index = -99;
		for i in probabilities.domain
		{
			temp_sum += probabilities[i];
			if r <= temp_sum
			{
				the_index = i;
				break;
			}
		}
		return elements[the_index];
	}

    proc fast_adjusted_erdos_renyi_hypergraph(graph, vertices_domain, edges_domain, p) {
	var desired_vertex_degrees = [vertices_domain]: real;
	var desired_edge_degrees = [edges_domain]: real;
	var num_vertices = vertices_domain.size;
	var num_edges = edges_domain.size;
	forall i in vertices_domain{
		desired_vertex_degrees[i] = num_edges*p;
	}
	forall i in edges_domain{
		desired_edge_degrees[i] = num_vertices*p;
	}
	var inclusions_to_add = num_vertices*num_edges*log(p/(1-p)): int;
	graph = fast_hypergraph_chung_lu(graph, vertices_domain, edges_domain, desired_vertex_degrees, desired_edge_degrees, inclusions_to_add);
	return graph;
    }

	//Pending: Take seed as input
    proc erdos_renyi_hypergraph(num_vertices, num_edges, p) {
        var randStream: RandomStream(real) = new RandomStream(real, 123);
        var graph = new AdjListHyperGraph(num_vertices, num_edges);
        forall vertex in graph.vertices_dom
		{
			forall edge in graph.edges_dom
			{
				var nextRand = randStream.getNext();
				if nextRand <= p then
					graph.add_inclusion(vertex, edge);
			}
		}        
        return graph;
    }
    
	//Following the pseudo code provided in the paper: Measuring and Modeling Bipartite Graphs with Community Structure
	//proc fast_hypergraph_chung_lu(graph, num_vertices, num_edges, desired_vertex_degrees, desired_edge_degrees, inclusions_to_add){
	//	var sum_degrees = + reduce desired_vertex_degrees:int;
	//	var vertex_probabilities: [1..num_vertices] real;
	//	var edge_probabilities: [1..num_edges] real;
	//	
	//	forall idx in desired_vertex_degrees.domain{
	//		vertex_probabilities[idx] = desired_vertex_degrees[idx]/sum_degrees:real;
	//	}
	//	forall idx in desired_edge_degrees.domain{
	//		edge_probabilities[idx] = desired_edge_degrees[idx]/sum_degrees:real;
	//	}
	//	
	//	forall k in 1..inclusions_to_add
	//	{
	//		var vertex = get_random_element(desired_vertex_degrees, vertex_probabilities);
	//		var edge = get_random_element(desired_edge_degrees, edge_probabilities);
	//		//writeln("vertex,edge: ",vertex, edge);
	//		graph.add_inclusion(vertex, edge);//How to check duplicate edge??
	//	}
	//	return graph;
    	//}
	
	proc fast_hypergraph_chung_lu(graph, vertices_domain, edges_domain, desired_vertex_degrees, desired_edge_degrees, inclusions_to_add){
		var sum_degrees = + reduce desired_vertex_degrees:int;
		var vertex_probabilities: [vertices_domain] real;
		var edge_probabilities: [edges_domain] real;
		forall idx in vertices_domain{
			vertex_probabilities[idx] = desired_vertex_degrees[idx]/sum_degrees:real;
		}
		forall idx in edges_domain{
			edge_probabilities[idx] = desired_edge_degrees[idx]/sum_degrees:real;
		}
		forall k in 1..inclusions_to_add
		{
			var vertex = get_random_element(vertices_domain, vertex_probabilities);
			var edge = get_random_element(edges_domain, edge_probabilities);
			//writeln("vertex,edge: ",vertex, edge);
			graph.add_inclusion(vertex, edge);//How to check duplicate edge??
		}
		return graph;	
	}

	proc fast_adjusted_hypergraph_chung_lu(graph, num_vertices, num_edges, desired_vertex_degrees, desired_edge_degrees){
		var inclusions_to_add =  + reduce desired_vertex_degrees:int;
		return fast_hypergraph_chung_lu(graph, num_vertices, num_edges, desired_vertex_degrees, desired_edge_degrees, inclusions_to_add);
	}

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
	
	proc bter_hypergraph(input_graph){
		//var original_vertex_degrees: int = input_graph.get_vertex_degrees();
		//var original_edge_degrees: int = input_graph.get_edge_degrees();
		create_input_data_lists();
		var idv: int;
		var idE: int;
		var numV: int;
		var numE: int;
		var nV : int;
		var nE : int;
		preprocess_bter();
		var graph = AdjListHyperGraph(numV, numE);
		while (idv <= numV && idE <= numE){
			compute_params_for_affinity_blocks();
			if (idv > numV || idE > numE){
				break; //make sure the "break" statement is the correct syntax
			}
			else{
				var vertices_domain : domain(int) = {idv..idv + nV};//check syntax
				var edges_domain : domain(int) = {idE..idE + nE};//check syntax
				//fast_adjusted_erdos_renyi_hypergraph(graph, vertices_domain, edges_domain, p);
			}
			//idv += nV;
			//idE += nE;
		}
		//var vertex_degrees: int = graph.get_vertex_degrees();
		//var edge_degrees: int = graph.get_edge_degrees();
		//var vertex_degree_diff = original_vertex_degrees - vertex_degrees;//check syntax
		//var edge_degree_diff = original_edge_degrees - edge_degrees;//check syntax
		//go through and replace negative values with 0s
		//var sum_of_vertex_diff = + reduce vertex_degree_diff:int;
		//var sum_of_edges_diff = + reduce edge_degree_diff:int;
		//var inclusions_to_add = max(sum_of_vertex_diff, sum_of_edges_diff);//check with Sinan if taking max() is correct
		//fast_hypergraph_chung_lu(graph, graph.vertices_dom, graph.edges_dom, vertex_degree_diff, edge_degree_diff, inclusions_to_add);
		return graph;
	}
  
}
