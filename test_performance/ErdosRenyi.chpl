use CHGL;
use Time;
use Random;

/* Performance Test for ChungLu algorithm */
config const isPrivatized = true;
config const numVertices = 1024;
config const isNaive = false;
config const isBuffered = true;
config const numEdges = numVertices * 2;
config const doCommDiagnostics = false;
config const probability = 0.1;
var edgeProbability = probability;
config const doVerboseComm = false;
config const doVisualDebug = false;

beginProfile("ErdosRenyiBenchmark-VisualDebug");

var graph = new AdjListHyperGraph(numVertices, numEdges, new Cyclic(startIdx=0, targetLocales=Locales));
var timer = new Timer();
timer.start();
generateErdosRenyi(graph, edgeProbability);
timer.stop();
graph.destroy();


writeln("Time:", timer.elapsed());
writeln("Probability:", edgeProbability);
writeln("Nodes:", numLocales);
writeln("NumVertices:", numVertices);
writeln("NumEdges:", numEdges);
writeln("ProbabilityMultiple:", probability);
writeln("Naive:", isNaive);
writeln("Contention:", Debug.contentionCnt);
writeln("maxTaskPar:", here.maxTaskPar);

endProfile();