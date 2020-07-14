use CHGL;
use BlockDist;
use Traversal;
use Metrics;

var graph = new AdjListHyperGraph(numVertices = 10, numEdges = 10);
for v in 0..4 {
  for e in 0..6 {
    graph.addInclusion(v,e);
  }
}
for v in 5..9 {
  for e in 7..9 {
    graph.addInclusion(v,e);
  }
}

config const source = 0; //source edge
config const s = 1;   
config const target = 1;

var s_distance =  sDistance(graph, source, target, s);
writeln(s_distance);
