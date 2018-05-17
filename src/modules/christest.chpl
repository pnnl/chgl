	proc get_random_element(elements, probabilities,randValue){
		var elist : [1..elements.size] int;
		var count = 0;
		for each in elements{
			count += 1;
			elist[count] = each;
		}
		var temp_sum = 0.0: real;
		var the_index = -99;
		for i in probabilities.domain do
		{
			temp_sum += probabilities[i];
			if randValue <= temp_sum
			{
				the_index = i;
				break;
			}
		}
		return elist[1];
	}


    proc fast_hypergraph_chung_lu(graph, vertices_domain, edges_domain, desired_vertex_degrees, desired_edge_degrees, inclusions_to_add){
		var sum_degrees = + reduce desired_vertex_degrees:real;
		//var vertex_probabilities: [vertices_domain] real;
		//var edge_probabilities: [edges_domain] real;
		var randStream: RandomStream(real) = new RandomStream(real);
		//forall idx in vertices_domain{
		var vertex_probabilities = desired_vertex_degrees/sum_degrees: real;
		//}
		//forall idx in edges_domain{
		var edge_probabilities = desired_edge_degrees/sum_degrees: real;
		//}
		forall k in 1..inclusions_to_add
		{
			var vertex = get_random_element(vertices_domain, vertex_probabilities,randStream.getNth(k)) - 1;
			var edge = get_random_element(edges_domain, edge_probabilities,randStream.getNth(k+inclusions_to_add));
			
			if graph.check_unique(vertex,edge){
				graph.add_inclusion(vertex, edge);//How to check duplicate edge??
			}
		}
		return graph;
	}