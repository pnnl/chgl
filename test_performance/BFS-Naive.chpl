use RangeChunk;
use WorkQueue;
use CyclicDist;
use Vectors;
use Utilities;
use Barriers;
use AllLocalesBarriers;
use DynamicAggregationBuffer;

config const dataset = "../data/karate.mtx_csr.bin";
config const numEdgesPresent = true;
config const doWorkStealing = true;

var numVertices : uint(64);
var numEdges : uint(64);

var globalTimer = new Timer();
var timer = new Timer();
globalTimer.start();
timer.start();

// TODO: Perform two phases: First phase reads all offsets into task-local array,
// next one reads from those offsets with a single reader (monotonically increasing order of offsets)
try! {
  var f = open(dataset, iomode.r, style = new iostyle(binary=1));   
  var reader = f.reader();
  
  // Read in |V| and |E|
  
  reader.read(numVertices);
  debug("|V| = " + numVertices);
  if numEdgesPresent {
    reader.read(numEdges);
    debug("|E| = " + numEdges);
  }
  reader.close();
  f.close();
}

var verticesDom = {0..#numVertices} dmapped Cyclic(startIdx=0);
var vertices : [verticesDom] unmanaged Vector(int);

try! {
  // On each node, independently process the file and offsets...
  coforall loc in Locales do on loc {
    var f = open(dataset, iomode.r, style = new iostyle(binary=1));    
    // Obtain offset for indices that are local to each node...
    var dom = verticesDom.localSubdomain();
    coforall chunk in chunks(dom.low..dom.high by dom.stride, here.maxTaskPar) {
      var reader = f.reader(locking=false);
      for idx in chunk {
        reader.mark();
        // Open file again and skip to portion of file we want...
        const headerOffset = if numEdgesPresent then 16 else 8;
        reader.advance(headerOffset + idx * 8);

        // Read our beginning and ending offset... since the ending is the next
        // offset minus one, we can just read it from the file and avoid
        // unnecessary communication with other nodes.
        var beginOffset : uint(64);
        var endOffset : uint(64);
        reader.read(beginOffset);
        reader.read(endOffset);
        endOffset -= 1;

        // Advance to current idx's offset...
        var skip = ((numVertices - idx:uint - 1:uint) + beginOffset) * 8;
        reader.advance(skip:int);


        // Pre-allocate buffer for vector and read directly into it
        var vec = new unmanaged Vector(int, endOffset - beginOffset + 1);
        reader.readBytes(c_ptrTo(vec.arr[0]), ((endOffset - beginOffset + 1) * 8) : ssize_t);
        vec.sz = (endOffset - beginOffset + 1) : int;
        vec.sort();
        vertices[idx] = vec;
        reader.revert();
      }
    }
    f.close();
  }
}

timer.stop();
writeln("Initialization in ", timer.elapsed(), "s");
timer.clear();

beginProfile("BFS-Naive-Perf");
var current = new WorkQueue(int, 1024 * 1024, new DuplicateCoalescer(int, -1));
var next = new WorkQueue(int, 1024 * 1024, new DuplicateCoalescer(int, -1));
var currTD = new TerminationDetector(1);
var nextTD = new TerminationDetector(0);
current.addWork(0, vertices[0].locale);
current.flush();
var visited : [verticesDom] atomic bool;
if CHPL_NETWORK_ATOMICS != "none" then visited[0].write(true);
var numPhases = 1;
var lastTime : real;
timer.start();
while !current.isEmpty() || !currTD.hasTerminated() {
  writeln("Level #", numPhases, " has ", current.globalSize, " elements...");
  forall vertex in doWorkLoop(current, currTD, doWorkStealing=doWorkStealing) {
    if vertex != -1 && (CHPL_NETWORK_ATOMICS != "none" || visited[vertex].testAndSet() == false) {
      for neighbor in vertices[vertex] {
        if CHPL_NETWORK_ATOMICS != "none" && visited[neighbor].testAndSet() == true {
          continue;
        }
        nextTD.started(1);
        const loc = vertices[neighbor].locale;
        next.addWork(neighbor, loc);
      }
    } 
    currTD.finished(1);
  }
  next.flush();
  next <=> current;
  nextTD <=> currTD;
  var currTime = timer.elapsed();
  writeln("Finished phase #", numPhases, " in ", currTime - lastTime, "s");
  lastTime = currTime;
  numPhases += 1;
}

timer.stop();
globalTimer.stop();
writeln("|V| = ", numVertices, ", |E| = ", numEdges);
writeln("BFS: ", timer.elapsed());
writeln("Total: ", globalTimer.elapsed());
endProfile(); 

