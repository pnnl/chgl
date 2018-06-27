use AdjListHyperGraph;
use CommDiagnostics;
use Generation;
use Time;

/* Performance Test for ChungLu algorithm */
config const numVertices = 1024 * 1024;
config const isNaive = false;
config const numEdges = numVertices * 2;
config const profileCommunications = false;
config const probability = .01;
var edgeProbability = probability;
config param profileVerboseCommunications = false;

if profileCommunications then startCommDiagnostics();
if profileVerboseCommunications then startVerboseComm();

var graph = new AdjListHyperGraph(numVertices, numEdges, new Cyclic(startIdx=0, targetLocales=Locales));
var timer = new Timer();
timer.start();
if isNaive then erdos_renyi_hypergraph(graph, graph.verticesDomain, graph.edgesDomain, edgeProbability);
else fast_simple_er(graph, edgeProbability);
timer.stop();


writeln("Time:", timer.elapsed());
writeln("Probability:", edgeProbability);
writeln("Nodes:", numLocales);
writeln("NumVertices:", numVertices);
writeln("NumEdges:", numEdges);
writeln("ProbabilityMultiple:", probability);
writeln("Naive:", isNaive);
writeln("Contention:", Debug.contentionCnt);
writeln("maxTaskPar:", here.maxTaskPar);

if profileCommunications then writeln(getCommDiagnostics());
