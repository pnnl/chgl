use AdjListHyperGraphs;

var prob = 0.6: real;
var num_vertices = 10: int;
var num_edges = 15: int;
var num_inclusions = 0: int;
var graph = new AdjListHyperGraph(num_vertices, num_edges);
var initial: int = 0;
var count: int = 0;
for e in 0..count-1 {
	for o in graph.incidence(graph.toVertex(e)) {
		initial += 1;
	}
}
var new_graph = generateErdosRenyi(graph, prob);
count = 0;
for e in graph.vertices{
	count += 1;
}
var edgecount: int = 0;
for e in 0..count-1{
	for o in graph.incidence(graph.toVertex(e)) {
		edgecount+=1;
	}
}
writeln(edgecount > initial);
