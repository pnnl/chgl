module Generation {
  use IO;
  use AdjListHyperGraph;
  
    proc random_boolean(p) {
      #return a random boolean accordingly to probability p
    }

    proc erdos_renyi_hypergraph(num_vertices, num_edges, p) {
        const vertex_domain = {1..num_nodes} dmapped Cyclic(startIdx=0);
        const edge_domain = {1..num_edges} dmapped Cyclic(startIdx=0);
        var graph = new AdjListHyperGraph(vertices_dom = vertex_domain, edges_dom = edge_domain);
        for vertex in vertex_domain do
            for edge in edge_domain do
                if random_boolean(p) then
                    graph.add_inclusion(vertex, edge);
        return graph;
    }
    
    proc chung_lu_hypergraph(desired_degrees){}
    
    proc bter_hypergraph(){}
  
}
