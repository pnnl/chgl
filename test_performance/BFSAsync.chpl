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

beginProfile("BFSAsync-profile");
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

var wq = new WorkQueue(graph.vDescType, 1024 * 1024);
var td = new TerminationDetector(1);
wq.addWork(graph.toVertex(0));
var visited : [graph.verticesDomain] atomic bool;
timer.start();
forall vertex in doWorkLoop(wq, td) {
  // Set as visited here...
  var haveVisited : bool;
  local do haveVisited = visited[vertex.id].testAndSet();
  if !haveVisited {
    for neighbor in graph.neighbors(vertex) {
      td.started(1);
      wq.addWork(neighbor, graph.getLocale(neighbor));
    }
  }
  td.finished(1);
}
writeln("Completed BFS in ", timer.elapsed(), "s");

var numVisited : int;
forall visit in visited with (+ reduce numVisited) {
  if visit.read() then numVisited += 1;
} 
writeln("Visited ", numVisited, " vertices...");
endProfile();
