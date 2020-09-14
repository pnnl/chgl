use AdjListHyperGraphs;

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


for v in graph.getVertices() {
  for s in 1..9 {
    for vv in graph.walk(v, s) {
      writeln(v, " can ", s, "-walk to ", vv);
    }
  }
}
