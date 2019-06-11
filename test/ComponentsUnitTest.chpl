use CHGL;

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

for s in 1..10 {
  writeln("Calculating components for s = ", s, "...");
  var nComponents : int;
  for component in getVertexComponents(graph, s) {
    writeln("Vertex Component #", nComponents, ": ", component.size());
    nComponents += 1;
  }
  nComponents = 0;
  for component in getEdgeComponents(graph, s) {
    writeln("Edge Component #", nComponents, ": ", component.size());
    nComponents += 1;
  }
  nComponents = 0;
}

writeln(graph.walk(graph.toVertex(5), 3));
writeln(graph.incidence(graph.toVertex(5)));
