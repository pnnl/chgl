use Graph;
use WorkQueue;
use CyclicDist;
use BinReader;
use Visualize;
use Time;
use VisualDebug;
use CommDiagnostics;
use Utilities;

config const dataset = "../data/karate.mtx_csr.bin";

beginProfile("BFS-profile");
var timer = new Timer();
timer.start();
var graph = binToGraph(dataset);
timer.stop();
writeln("Graph generation for ", dataset, " took ", timer.elapsed(), "s");
timer.clear();
writeln("|V| = ", graph.numVertices, " and |E| = ", graph.numEdges);

timer.start();
graph.simplify();
timer.stop();
writeln("Simplified graph in ", timer.elapsed(), "s");
timer.clear();

timer.start();
graph.validateCache();
timer.stop();
writeln("Generated cache in ", timer.elapsed(), "s");
timer.clear();

var current = new WorkQueue(graph.vDescType);
var next = new WorkQueue(graph.vDescType);
var currTD = new TerminationDetector(1);
var nextTD = new TerminationDetector(0);
current.addWork(graph.toVertex(0));
var visited : [graph.verticesDomain] atomic bool;
var numPhases = 1;
var lastTime : real;
timer.start();
while !current.isEmpty() || !currTD.hasTerminated() {
  writeln("Level #", numPhases, " has ", current.globalSize, " elements...");
  forall vertex in doWorkLoop(current, currTD) {
    // Set as visited here...
    var haveVisited : bool;
    local do haveVisited = visited[vertex.id].testAndSet();
    if !haveVisited {
      for neighbor in graph.neighbors(vertex) {
        nextTD.started(1);
        next.addWork(neighbor, graph.getLocale(neighbor));
      }
    }  
    currTD.finished(1);
  }
  next <=> current;
  nextTD <=> currTD;
  var currTime = timer.elapsed();
  writeln("Finished phase #", numPhases, " in ", currTime - lastTime, "s");
  lastTime = currTime;
  numPhases += 1;
}
writeln("Completed BFS in ", timer.elapsed(), "s");
endProfile();
