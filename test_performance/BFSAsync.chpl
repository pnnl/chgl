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
if CHPL_NETWORK_ATOMICS != "none" then visited[0].write(true);
timer.start();
forall vertex in doWorkLoop(wq, td) {
  // If no network (RDMA) atomic support, visit current vertex which is
  // guaranteed to be on the current locale, but only if it hasn't been visited before.
  // If RDMA atomics are supported, we check our neighbor to see if it has been viisted.
  if CHPL_NETWORK_ATOMICS != "none" || visited[vertex.id].testAndSet() == false {
    for neighbor in graph.neighbors(vertex) {
      if CHPL_NETWORK_ATOMICS != "none" && visited[neighbor.id].testAndSet() == true {
        continue;
      }
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
