use WorkQueue;
use BlockDist;
use Vectors;
use Utilities;
use Barriers;
use AllLocalesBarriers;
use DynamicAggregationBuffer;

config const dataset = "../data/karate.mtx_csr.bin";

try! {
  var time = new Timer();
  time.start();
  var f = open(dataset, iomode.r, style = new iostyle(binary=1));   
  var reader = f.reader();
  
  // Read in |V| and |E|
  var numVertices : uint(64);
  var numEdges : uint(64);
  reader.read(numVertices);
  reader.read(numEdges);
  debug("|V| = " + numVertices);
  debug("|E| = " + numEdges);
  reader.close();
  f.close();
  
  
  var D = {0..#numVertices} dmapped Block(boundingBox={0..#numVertices});
  var A : [D] owned Vector(int);
  
  // On each node, independently process the file and offsets...
  coforall loc in Locales do on loc {
    var f = open(dataset, iomode.r, style = new iostyle(binary=1));    
    debug("Node #", here.id, " beginning to process localSubdomain ", D.localSubdomain());
    // Obtain offset for indices that are local to each node...
    forall idx in D.localSubdomain() {
      // Open file again and skip to portion of file we want...
      var reader = f.reader();
      reader.advance(16 + idx * 8);
      debug("Starting at file offset ", reader.offset(), " for offset table of idx #", idx);

      // Read our beginning and ending offset... since the ending is the next
      // offset minus one, we can just read it from the file and avoid
      // unnecessary communication with other nodes.
      var beginOffset : uint(64);
      var endOffset : uint(64);
      reader.read(beginOffset);
      reader.read(endOffset);
      endOffset -= 1;
      debug("Offsets into adjacency list for idx #", idx, " are ", beginOffset..endOffset);

      // Advance to current idx's offset...
      var skip = ((numVertices - idx:uint - 1:uint) + beginOffset) * 8;
      reader.advance(skip:int);
      debug("Adjacency list offset begins at file offset ", reader.offset());


      // TODO: Request storage space in advance for graph...
      // Read in adjacency list for edges... Since 'addInclusion' already push_back
      // for the matching vertices and edges, we only need to do this once.
      A[idx] = new owned VectorImpl(int, {0..#(endOffset - beginOffset + 1)});
      for beginOffset : int..endOffset : int {
        var edge : uint(64);
        reader.read(edge);
        A[idx].append(edge : int);
        debug("Added inclusion for vertex #", idx, " and edge #", edge);
      }
      A[idx].sort();
      reader.close();
    }
  }
  
  time.stop();
  writeln("Initialization in ", time.elapsed(), "s");
  time.clear();
  
  allLocalesBarrier.reset(here.maxTaskPar);

  var current = new WorkQueue(int, WorkQueueUnlimitedAggregation);
  var next = new WorkQueue(int, WorkQueueUnlimitedAggregation);
  current.addWork(0, A[0].locale);
  current.flush();
  var visited : [D] atomic bool;
  if CHPL_NETWORK_ATOMICS != "none" then visited[0].write(true);
  var lastTime : real;
  time.start();
  var keepAlive : atomic bool;
  keepAlive.write(true);
  coforall loc in Locales do on loc {
    coforall tid in 0..#here.maxTaskPar {
      var _current = current;
      var _next = next;
      var numPhases = 0;
      while true {
        var (hasVertex, vertex) = _current.getWork();
        if !hasVertex {
          allLocalesBarrier.barrier();
          if here.id == 0 && tid == 0 {
            _next.flush();
            var elemsLeft = _next.globalSize;
            writeln("Level #", numPhases, " has ", elemsLeft, " elements...");
            if elemsLeft == 0 then keepAlive.write(false);
          }
          allLocalesBarrier.barrier();
          if keepAlive.read() == false then break;
          _next.pid <=> _current.pid;
          _next.instance <=> _current.instance;
          numPhases += 1;
          continue;
        }

        // Set as visited here...
        if CHPL_NETWORK_ATOMICS != "none" || visited[vertex].testAndSet() == false {
          for neighbor in A[vertex] {
            if CHPL_NETWORK_ATOMICS != "none" && visited[neighbor].testAndSet() == true {
              continue;
            }
            _next.addWork(neighbor, A[neighbor].locale);
          }
        } 
      }
    }
  }
  writeln("|V| = ", numVertices, ", |E| = ", numEdges, ", Completed BFS in ", time.elapsed(), "s");
  f.close();
}

