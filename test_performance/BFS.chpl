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
config const printTiming = false;

beginProfile("BFS-profile");
var globalTimer = new Timer();
globalTimer.start();
var timer = new Timer();
timer.start();
var graph = binToGraph(dataset);
timer.stop();
if printTiming then writeln("Graph Generation (2-Uniform): ", timer.elapsed());
timer.clear();

timer.start();
graph.simplify();
timer.stop();
if printTiming then writeln("Removed Duplicates (2-Uniform): ", timer.elapsed());
timer.clear();

/*timer.start();
graph.validateCache();
timer.stop();
writeln("Generated Cache (2-Uniform): ", timer.elapsed());
timer.clear();*/

var current = new WorkQueue(graph.vDescType, WorkQueueUnlimitedAggregation);
var next = new WorkQueue(graph.vDescType, WorkQueueUnlimitedAggregation);
var currTD = new TerminationDetector(1);
var nextTD = new TerminationDetector(0);
current.addWork(graph.toVertex(0));
var visited : [graph.verticesDomain] atomic bool;
if CHPL_NETWORK_ATOMICS != "none" then visited[0].write(true);
var numPhases = 1;
var lastTime : real;
timer.start();
while !current.isEmpty() || !currTD.hasTerminated() {
  writeln("Level #", numPhases, " has ", current.globalSize, " elements...");
  forall vertex in doWorkLoop(current, currTD) {
    // Set as visited here...
    if CHPL_NETWORK_ATOMICS != "none" || visited[vertex.id].testAndSet() == false {
      forall neighbor in graph.neighbors(vertex) {
        if CHPL_NETWORK_ATOMICS != "none" && visited[neighbor.id].testAndSet() == true {
          continue;
        }
        nextTD.started(1);
        next.addWork(neighbor, graph.getLocale(neighbor));
      }
    } 
    currTD.finished(1);
  }
  next.flush();
  next <=> current;
  nextTD <=> currTD;
  var currTime = timer.elapsed();
  if printTiming then writeln("Phase #", numPhases, " (2-Uniform): ", currTime - lastTime);
  lastTime = currTime;
  numPhases += 1;
}
if printTiming then writeln("BFS (2-Uniform): ", timer.elapsed());
if printTiming then writeln("Total (2-Uniform): ", timer.elapsed());
endProfile();
