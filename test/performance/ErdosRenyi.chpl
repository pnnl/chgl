use AdjListHyperGraph;
use Memory;
use CommDiagnostics;
use VisualDebug;
use Generation;
use Time;
use Random;

config const numVertices = 128 * 1024;
config const numEdges = numVertices * 2;
config const doCommDiagnostics = false;
config const doVerboseComm = false;
config const doVisualDebug = false;
config const visualDebugOutput = "ErdosRenyi-VisualDebug";
config const probability = .01;

if doCommDiagnostics then startCommDiagnostics();
if doVerboseComm then startVerboseComm();
if doVisualDebug then startVdebug(visualDebugOutput);

if doVisualDebug then tagVdebug("Initialization");
var graph = new AdjListHyperGraph(numVertices, numEdges, new Cyclic(startIdx=0));
if doVisualDebug then tagVdebug("Generation");
var timer = new Timer();
timer.start();
generateErdosRenyi(graph, probability);
timer.stop();

if doCommDiagnostics then writeln(getCommDiagnostics());
if doVerboseComm then stopVerboseComm();
if doVisualDebug then stopVdebug();

writeln("Time:", timer.elapsed());
writeln("Probability:", probability);
writeln("Nodes:", numLocales);
writeln("NumVertices:", numVertices);
writeln("NumEdges:", numEdges);
writeln("Memory Used: ", memoryUsed());
writeln("ProbabilityMultiple:", probability);
writeln("Contention:", Debug.contentionCnt);
writeln("maxTaskPar:", here.maxTaskPar);

