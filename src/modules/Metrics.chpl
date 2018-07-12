use AdjListHyperGraph;
use FIFOChannel;

/*
  Obtains all sequences of length k that the hyperedge e can walk to; we can walk from e to e'
  if the intersection of the neighbors of e and e' are of at least size s. The results are
  returned via a tuple of rank k.
*/
proc walk(graph, e : graph.eDescType, s = 1, param k = 2) : Channel(k * graph.eDescType) {
  type pathType = k * graph.eDescType;
  var inchan = new Channel(pathType);
  var outchan = new Channel(pathType);
  inchan.pair(outchan);
  
  /*
    Visits edge and determines if we can walk to neighbor; if we can, then we visit each neighbor.
    Recursion is bound by k.
  */
  proc visitEdge(edge : graph.eDescType, neighbor : graph.eDescType, depth, path : pathType) {
    if graph.getEdge(edge).intersection(neighbor).size() >= s {
      const p = path;
      p[depth] = neighbor;
      
      // If we have found our k'th hyperedge, we have finished...
      if depth == k {
        outchan.send(p);
        return;
      }

      // Otherwise, visit all two-hop neighbors...
      for v in graph.getNeighbors(neighbor) {
        for twoHopNeighbors in graph.getNeighbors(v) {
          // Check if we already processed this edge...
          var processed = false;
          for processedNeighbor in path {
            if processedNeighbor == twoHopNeighbor {
              processed = true;
              break;
            }
          }

          if !processed {
            visitEdge(neighbor, twoHopNeighbor, depth + 1, p);
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
    for v in graph.getNeighbors(e) {
      for twoHopNeighbor in graph.getNeighbors(v) {
          var p : pathType;
          p[1] = e;
          p[2] = twoHopNeighbor;
          visitEdge(e, twoHopNeighbor, 2, p); 
      }
    }
    outchan.close();
  }

  // Return input end...
  return inchan;
}
