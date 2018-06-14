use AdjListHyperGraph;
use CyclicDist;
use Generation;

var prob = 0.6; real;
var num_vertices = 1024: int;
var num_edges = 2048;
var num_inclusions = 0: int;
var graph = new AdjListHyperGraph(num_vertices, num_edges);
graph = erdos_renyi_hypergraph(graph, graph.verticesDomain, graph.edgesDomain, prob);
for vertex_id in graph.verticesDomain {
	num_inclusions += graph.getVertex(vertex_id).neighborList.size;
}
var expected_num_inclusions = prob*num_vertices*num_edges;
var half_width = expected_num_inclusions * 0.5;
//writeln(num_inclusions);
var test_passed = false: bool;
test_passed = num_inclusions >= (expected_num_inclusions - half_width) && num_inclusions <= (expected_num_inclusions + half_width);
writeln(test_passed);
if Debug.ALHG_PROFILE_CONTENTION then writeln("Contended Access: " + Debug.contentionCnt.read());
