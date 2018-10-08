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

writeln("Calculating components for s = 1...");
var nComponents = 1;
for component in getVertexComponents(graph, s = 1) {
  writeln("#", nComponents, ": ", component);
  nComponents += 1;
}
nComponents = 0;
for component in getEdgeComponents(graph, s = 1) {
  writeln("#", nComponents, ": ", component);
  nComponents += 1;
}
nComponents = 0;

writeln("Calculating components for s = 2...");
for component in getVertexComponents(graph, s = 2) {
  writeln("#", nComponents, ": ", component);
  nComponents += 1;
}
nComponents = 0;
for component in getEdgeComponents(graph, s = 2) {
  writeln("#", nComponents, ": ", component);
  nComponents += 1;
}
nComponents = 0;

writeln("Calculating components for s = 3...");
for component in getVertexComponents(graph, s = 3) {
  writeln("#", nComponents, ": ", component);
  nComponents += 1;
}
nComponents = 0;
for component in getEdgeComponents(graph, s = 3) {
  writeln("#", nComponents, ": ", component);
  nComponents += 1;
}
nComponents = 0;

writeln(graph.walk(graph.toVertex(5), 3));
writeln(graph.neighbors(graph.toVertex(5)));
