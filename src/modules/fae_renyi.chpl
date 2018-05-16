use Generation;
use AdjListHyperGraph;
use Math;

var num_vertices = 10 : int;
var num_edges = 15 : int;

var graph = new AdjListHyperGraph(num_vertices, num_edges);

//writeln(graph.forEachVertexDegrees);

var faer_graph = fast_adjusted_erdos_renyi_hypergraph(graph, graph.vertices_dom, graph.edges_dom, 0.6);

writeln("done");
