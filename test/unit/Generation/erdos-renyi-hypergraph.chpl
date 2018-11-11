use AdjListHyperGraph;
use CyclicDist;
use Generation;

var prob = 0.6; real;
var num_vertices = 1024: int;
var num_edges = 2048;
var num_inclusions = 0: int;
var graph = new AdjListHyperGraph(num_vertices, num_edges);
graph = generateErdosRenyi(graph, prob);
graph.removeDuplicates();
for vertex_id in graph.getVertices() {
	num_inclusions += graph.degree(vertex_id);
}
var expected_num_inclusions = prob*num_vertices*num_edges;
var half_width = expected_num_inclusions * 0.5;
var test_passed = false: bool;
test_passed = num_inclusions >= (expected_num_inclusions - half_width) && num_inclusions <= (expected_num_inclusions + half_width);
writeln(test_passed);
if test_passed == false then writeln("numInclusions(", num_inclusions, ") not in ", (expected_num_inclusions - half_width), " to ", (expected_num_inclusions + half_width));
if Debug.ALHG_PROFILE_CONTENTION then writeln("Contended Access: " + Debug.contentionCnt.read());
