use AdjListHyperGraph;
use CyclicDist;
use Generation;

var prob = 0.6: real;
var num_vertices = 10: int;
var num_edges = 15;
var num_inclusions = 0: int;
var graph = erdos_renyi_hypergraph(num_vertices, num_edges, prob);
for vertex_id in graph.vertices_dom {
	num_inclusions += graph.vertices(vertex_id).neighborList.size;
}
writeln(num_inclusions);
