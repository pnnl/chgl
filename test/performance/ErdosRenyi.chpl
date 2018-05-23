use AdjListHyperGraph;
use CommDiagnostics;
use Generation;
use Time;

/* Performance Test for ChungLu algorithm */
config const numVertices = 1024 * 1024;
config const isNaive = false;
config const numEdges = numVertices * 2;
config const profileCommunications = false;
config const probability = 0.6;

if profileCommunications then startCommDiagnostics();

const vertex_domain = {0..#numVertices} dmapped Cyclic(startIdx=0);
const edge_domain = {0..#numEdges} dmapped Cyclic(startIdx=0);
var graph = new AdjListHyperGraph(vertex_domain, edge_domain);

var timer = new Timer();
timer.start();
if isNaive then erdos_renyi_hypergraph(graph, graph.vertices_dom, graph.edges_dom, probability);
else fast_adjusted_erdos_renyi_hypergraph(graph, graph.vertices_dom, graph.edges_dom, probability);
timer.stop();

writeln("Time:", timer.elapsed());
writeln("Nodes:", numLocales);
writeln("NumVertices:", numVertices);
writeln("NumEdges:", numEdges);
writeln("Probability:", probability);
writeln("Naive:", isNaive);

if profileCommunications then writeln(getCommDiagnostics);
