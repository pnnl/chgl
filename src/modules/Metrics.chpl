use AdjListHyperGraph;
use Generation;
use FIFOChannel;
use WorkQueue;
use TerminationDetector;
use ReplicatedVar;

/* 
  Represents 's-walk' state. We manage the current hyperedge sequence
  as well as our current neighbor.
*/
record WalkState {
  type edgeType;
  type vertexType;
  
  // The current sequences of edges that we have s-walked to.
  var sequenceDom = {0..-1};
  var sequence : [dom] stateType;
  
  // Our current neighbor and if we are checking them.
  // Since we need to find two-hop neighbors, we need
  // to do them on the respective locale as well.
  var neighbor : vertexType;
  var checkingNeighbor : bool;

  proc init(other) {
    this.edgeType = other.edgeType;
    this.vertexType = other.vertexType;
    this.sequenceDom = other.sequenceDom;
    this.complete();
    this.sequence = other.sequence;
    this.neighbor = other.neighbor;
    this.checkingNeighbor = other.checkingNeighbor;
  }

  proc init(type edgeType, type vertexType, size = -1) {
    this.edgeType = edgeType;
    this.vertexType = vertexType;
    this.sequenceDom = {0..#size};
  }

  inline proc append(edge : edgeType) {
    this.sequence.push_back(edge);
  }

  inline proc setNeighbor(vertex : vertexType) {
    this.neighbor = vertex;
    this.checkingNeighbor = true;
  }

  inline proc unsetNeighbor() {
    this.checkingNeighbor = false;
  }

  inline proc isCheckingNeighbor() return this.checkingNeighbor;
  inline proc getNeighbor() return this.currentNeighbor;

  inline proc hasProcessed(edge : edgeType) {
    for e in sequence do if e.id == edge.id then return true;
    return false;
  }

  inline proc this(idx : integral) ref {
    return sequences[idx];
  }
}

proc walk(graph, s = 1, k = 2) {
  type edgeType = graph.edgeType;
  type vertexType = graph.vertexType;
  var workQueue = nil; // TODO
  var keepAlive : [rcDomain] bool;
  var terminationDetector : TerminationDetector;
  rcReplicate(keepAlive, true);
  
  // Insert initial states...
  forall e in graph.getEdges() with (in graph, in workQueue, in terminationDetector) {
    // Iterate over neighbors
    forall v in graph.getNeighbors(v) with (in graph, in workQueue, in terminationDetector, in e) {
      var state = new WalkState(edgeType, vertexType, 1);
      state[0] = e;
      state.setNeighbor(v);
      terminationDetector.start();
      workQueue.addWork(state, graph.getLocale(v));
    }
  }

  // With the queue populated, we can begin our work loop...
  // Spawn a new task to handle alerting each locale that they can stop...
  begin {
    terminationDetector.wait(minBackoff = 1, maxBackOff = 100);
    rcReplicate(keepAlive, false);
  }
  
  // Begin work queue loops; a task on each locale, and then spawn up to the
  // maxmimum parallelism on each respective locales. Each of the tasks will
  // wait on the replicated 'keepAlive' flag. Each time a state is created
  // and before it is added to the workQueue, the termination detector will
  // increment the number of tasks started, and whenever a state is finished
  // it will increment the number of tasks finished...
  coforall loc in Locales with (in graph, in workQueue, in terminationDetector) do on loc {
    coforall tid in 1..here.maxTaskPar {
      // TODO: 
    }
  }
  writeln(workQueue);
}

/*
  Obtains all sequences of length k that the hyperedge e can walk to; we can walk from e to e'
  if the intersection of the neighbors of e and e' are of at least size s. The results are
  returned via a tuple of rank k. This is performed serially on a single thread; attempts to
  parallelize this has resulted in undefined behavior, likely due to how we start a task
  that outlives its parent's scope.
*/
proc walk(graph, e, s = 1, param k = 2) {
  type pathType = k * e.type;
  var inchan = new Channel(pathType);
  var outchan = new Channel(pathType);
  inchan.pair(outchan);
  
  /*
    Visits edge and determines if we can walk to neighbor; if we can, then we visit each neighbor.
    Recursion is bound by k.
  */
  proc visitEdge(graph, edge, neighbor, depth, path : pathType, chan) {
    if edge.id == neighbor.id then return;
    var intersection = graph.intersection(edge, neighbor);
    if intersection.size >= s {
      var p = path;
      p[depth] = neighbor;
      
      // If we have found our k'th hyperedge, we have finished...
      if depth == k {
        chan.send(p);
        return;
      }

      // Otherwise, visit all two-hop neighbors...
      for v in graph.getNeighbors(neighbor) {
        for twoHopNeighbor in graph.getNeighbors(v) {
          // Check if we already processed this edge...
          var processed = false;
          for processedNeighbor in path {
            if processedNeighbor == twoHopNeighbor {
              processed = true;
              break;
            }
          }

          if !processed {
            visitEdge(graph, neighbor, twoHopNeighbor, depth + 1, p, chan);
          }
        }
      }
    }
  }

  if k == 1 {
    outchan.send((e,));
    outchan.close();
    return inchan;
  }

  // Handle asynchronously
  begin {
    // Special case: If k is 1, we're already done...
    var p : pathType;
    p[1] = e;
    for v in graph.getNeighbors(e) {
      for twoHopNeighbor in graph.getNeighbors(v) {
        if twoHopNeighbor != e { 
          visitEdge(graph, e, twoHopNeighbor, 2, p, outchan);
        }
      }
    }
    outchan.close();
  }

  // Return input end...
  return inchan;
}

proc main() {
  var graph = new AdjListHyperGraph(1024, 1024);
  generateErdosRenyiSMP(graph, 0.25);
  graph.removeDuplicates();
  walk(graph);
}
