use AdjListHyperGraph;
use FIFOChannel;

/*
  Obtains all sequences of length k that the hyperedge e can walk to; we can walk from e to e'
  if the intersection of the neighbors of e and e' are of at least size s. The results are
  returned via a tuple of rank k.
*/
proc walk(graph, e : graph.eDescType, s = 1, param k = 2) : Channel(k * graph.eDescType) {
  type chanType = k * graph.eDescType;
  var inchan = new Channel(chanType);
  var outchan = new Channel(chanType);
  inchan.pair(outchan);

  // Handle asynchronously
  begin {
    // TODO
  }

  // Return output end...
  return outchan;
}
