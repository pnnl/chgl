use AdjListHyperGraph;
use VisualDebug;
use Memory;
use CommDiagnostics;
use Generation;
use Time;
use Random;

/* Performance Test for ChungLu algorithm */
config const isPrivatized = true;
config const numVertices = 1024 * 1024;
config const isNaive = false;
config const isBuffered = true;
config const numEdges = numVertices * 2;
config const doCommDiagnostics = false;
config const probability = .01;
var edgeProbability = probability;
config const doVerboseComm = false;
config const doVisualDebug = false;

if doCommDiagnostics then startCommDiagnostics();
if doVerboseComm then startVerboseComm();
if doVisualDebug then startVdebug("ErdosRenyiBenchmark-VisualDebug");
if doVisualDebug then tagVdebug("Initialization");
var graph = new AdjListHyperGraph(numVertices, numEdges, new Cyclic(startIdx=0, targetLocales=Locales));
if doVisualDebug then tagVdebug("Generation");
var timer = new Timer();
timer.start();
generateErdosRenyi(graph, edgeProbability);
timer.stop();
if doVisualDebug then tagVdebug("Deinitialization");
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

if doVisualDebug then stopVdebug();
if doCommDiagnostics then writeln(getCommDiagnostics());
