module Generation {
  use IO;
  use Random;
  use CyclicDist;
  use AdjListHyperGraph;
  

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

	//Pending: Take seed as input
    proc erdos_renyi_hypergraph(num_vertices, num_edges, p) {
        var randStream: RandomStream(real) = new RandomStream(real, 123);
        const vertex_domain = {1..num_vertices} dmapped Cyclic(startIdx=0);
        const edge_domain = {1..num_edges} dmapped Cyclic(startIdx=0);
        var graph = new AdjListHyperGraph(vertices_dom = vertex_domain, edges_dom = edge_domain);
        forall vertex in vertex_domain
		{
			forall edge in edge_domain
			{
				var nextRand = randStream.getNext();
				if nextRand <= p then
					graph.add_inclusion(vertex, edge);
			}
		}        
        return graph;
    }
    
	//Following the pseudo code provided in the paper: Measuring and Modeling Bipartite Graphs with Community Structure
	proc fast_hypergraph_chung_lu(graph, num_vertices, num_edges, desired_vertex_degrees, desired_edge_degrees){
		var sum_degrees = + reduce desired_vertex_degrees:int;
		var vertex_probabilities: [1..num_vertices] real;
		var edge_probabilities: [1..num_edges] real;
		
		vertex_probabilities = desired_vertex_degrees/sum_degrees;
		edge_probabilities = desired_edge_degrees/sum_degrees;
		
		forall k in [1..sum_degrees]
		{
			var vertex = get_random_element(desired_vertex_degrees, vertex_probabilities);
			var edge = get_random_element(desired_edge_degrees, edge_probabilities);
			graph.add_inclusion(vertex, edge);//How to check duplicate edge??
		}
		return graph;
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
    
    // proc bter_hypergraph(){
    //     #calculate parameters
    //     #divide nodes up into blocks (using the parameter values)
    //     #while it is not possible to create any more subgraphs
    //         #for each block
    //             #erdos_renyi_hypergraph(block)
    //         #update variables
    //     #Chung-Lu
    // #}
  
}
