use Graph;
use WorkQueue;
use CyclicDist;
use BinReader;
use Visualize;

config const dataset = "../data/karate.mtx_csr.bin";
var graph = binToGraph(dataset);
writeln("|V| = ", graph.numVertices, " and |E| = ", graph.numEdges);

var current = new WorkQueue(graph.vDescType);
var next = new WorkQueue(graph.vDescType);
var currTD = new TerminationDetector(1);
var nextTD = new TerminationDetector(0);
current.addWork(graph.toVertex(0));
var visited : [graph.verticesDomain] atomic bool;
visited[0].write(true);
var numPhases = 1;
while !current.isEmpty() || !currTD.hasTerminated() {
  writeln("Level #", numPhases, " has ", current.globalSize, " elements...");
  forall vertex in doWorkLoop(current, currTD) {
    for neighbor in graph.neighbors(vertex) {
      if visited[neighbor.id].testAndSet() {
        continue;
      }
      nextTD.started(1);
      next.addWork(neighbor, graph.getLocale(neighbor));
    }
    currTD.finished(1);
  }
  next <=> current;
  nextTD <=> currTD;
  writeln("Finished phase #", numPhases);
  numPhases += 1;
}


