module Generation {
  use IO;
  use AdjListHyperGraph;
  
    proc random_boolean(p) {
      #return a random boolean accordingly to probability p
    }

    proc erdos_renyi_naive_hypergraph(num_vertices, num_edges, p) {
        const vertex_domain = {1..num_nodes} dmapped Cyclic(startIdx=0);
        const edge_domain = {1..num_edges} dmapped Cyclic(startIdx=0);
        var graph = new AdjListHyperGraph(vertices_dom = vertex_domain, edges_dom = edge_domain);
        for vertex in vertex_domain do
            for edge in edge_domain do
                if random_boolean(p) then
                    graph.add_inclusion(vertex, edge);
        return graph;
    }
    
    proc chung_lu_naive_hypergraph(desired_degrees, desired_num_edges){
        const vertex_domain = {1..num_nodes} dmapped Cyclic(startIdx=0);
        const edge_domain = {1..num_edges} dmapped Cyclic(startIdx=0);
        var graph = new AdjListHyperGraph(vertices_dom = vertex_domain, edges_dom = edge_domain);
        for vertex in vertex_domain do
            for edge in edge_domain do
                p = (desired_degrees[vertex]*desired_degrees[edge])/(2*desired_num_edges)
                if random_boolean(p) then
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
