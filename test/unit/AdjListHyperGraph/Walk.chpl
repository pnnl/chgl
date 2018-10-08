use AdjListHyperGraph;
use Components;

var graph = new AdjListHyperGraph(numVertices = 10, numEdges = 10);
forall v in 0..4 {
  forall e in 0..6 {
    graph.addInclusion(v,e);
  }
}
forall v in 5..9 {
  forall e in 7..9 {
    graph.addInclusion(v,e);
  }
}


for v in graph.getVertices() {
  for s in 1..9 {
    for vv in graph.walk(v, s) {
      writeln(v, " can ", s, "-walk to ", vv);
    }
  }
}
