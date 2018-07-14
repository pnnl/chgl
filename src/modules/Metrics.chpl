use AdjListHyperGraph;
use Generation;
use FIFOChannel;
use DistributedDeque;

record State {
  type wrapperType;
  var dom = {0..-1};
  var arr : [dom] wrapperType;

  proc init(other) {
    this.wrapperType = other.wrapperType;
    this.dom = other.dom;
    this.complete();
    this.arr = other.arr;
  }

  proc init(type wrapperType) {
    this.wrapperType = wrapperType;
  }
}
proc walk(graph, s = 1, k = 2) {
  type stateType = State(graph._value.eDescType);
  var workQueue = new DistDeque(stateType);
  forall e in graph.getEdges() {
    var state : stateType;;
    state.arr.push_back(e);
    workQueue.add(state);
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
