use AdjListHyperGraph;
use Generation;

var prob = 0.6: real;
var num_vertices = 10: int;
var num_edges = 15: int;
var num_inclusions = 0: int;
var graph = new AdjListHyperGraph(num_vertices, num_edges);
var initial: int = 0;
var count: int = 0;
for e in 0..count-1{
	for o in graph.vertices(e).neighborList{
		initial += 1;
	}
}
var new_graph = fast_adjusted_erdos_renyi_hypergraph(graph, graph.vertices_dom, graph.edges_dom, prob);
count = 0;
for e in graph.vertices{
	count += 1;
}
var edgecount: int = 0;
for e in 0..count-1{
	for o in graph.vertices(e).neighborList{
		edgecount+=1;
	}
}
writeln(edgecount > initial);
