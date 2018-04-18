module Generation {
  use IO;
  use Random;
  use AdjListHyperGraph;
  
    proc random_boolean(p) {
      #return a random boolean accordingly to probability p
    }
    
    proc get_random_element(edge_domain, probabilities) {
      #return a random element of a domain based on a probability distribution over the elements
    }

    proc erdos_renyi_hypergraph(num_vertices, num_edges, p) {
        var randStream: RandomStream(real) = new RandomStream(real);
		const vertex_domain = {1..num_nodes} dmapped Cyclic(startIdx=0);
        const edge_domain = {1..num_edges} dmapped Cyclic(startIdx=0);
        var graph = new AdjListHyperGraph(vertices_dom = vertex_domain, edges_dom = edge_domain);
        for vertex in vertex_domain do
            for edge in edge_domain do
                var nextRand = randStream.getNext();
                if nextRand >= p then
                    graph.add_inclusion(vertex, edge);
        return graph;
    }
    
    proc chung_lu_naive_hypergraph(desired_vertex_degrees, desired_edge_degrees, desired_num_edges){
        const vertex_domain = {1..num_nodes} dmapped Cyclic(startIdx=0);
        const edge_domain = {1..num_edges} dmapped Cyclic(startIdx=0);
        var graph = new AdjListHyperGraph(vertices_dom = vertex_domain, edges_dom = edge_domain);
        for vertex in vertex_domain do
            for edge in edge_domain do
                p = (desired_vertex_degrees[vertex]*desired_edge_degrees[edge])/(2*desired_num_edges); #this needs more work
                if random_boolean(p) then
                    graph.add_inclusion(vertex, edge);
        return graph;
    }
    
    proc chung_lu_fast_hypergraph(desired_vertex_degrees, desired_edge_degrees, desired_num_edges){
        const vertex_domain = {1..num_nodes} dmapped Cyclic(startIdx=0);
        const edge_domain = {1..num_edges} dmapped Cyclic(startIdx=0);
        var graph = new AdjListHyperGraph(vertices_dom = vertex_domain, edges_dom = edge_domain);
        var vertex_probabilities: [1..num_nodes] real;
        forall vertex in vertex_domain do
            p = desired_vertex_degrees[vertex]/desired_num_edges;
        var edge_probabilities: [1..num_edges] real;
        forall edge in edge_domain do
            p = desired_edge_degrees[edge]/desired_num_edges
        for k in {1..desired_num_edges} do
            vertex = get_random_element(vertex_domain, vertex_probabilities);
            edge = get_random_element(edge_domain, edge_probabilities);
            graph.add_inclusion(vertex, edge);
        return graph;
    }
    
    proc bter_hypergraph(){
        #calculate parameters
        #divide nodes up into blocks (using the parameter values)
        #while it is not possible to create any more subgraphs
            #for each block
                #erdos_renyi_hypergraph(block)
            #update variables
        #Chung-Lu
    }
  
}
