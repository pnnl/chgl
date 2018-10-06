use AdjListHyperGraph;
use Components;

var graph = new AdjListHyperGraph(numVertices = 4, numEdges = 3);
// Create a butterfly... (v0 -> e0), (e0 -> v2), (v2 -> e2), (e2 -> v0)
graph.addInclusion(0,0);
graph.addInclusion(2,0);
graph.addInclusion(2,2);

// Create a line... (v1 -> e1)
graph.addInclusion(1,1);


writeln("Calculating components for s = 1...");
for component in getVertexComponents(graph, s = 1) {
  writeln(component);
}
for component in getEdgeComponents(graph, s = 1) {
  writeln(component);
}

writeln("Calculating components for s = 2...");
for component in getVertexComponents(graph, s = 2) {
  writeln(component);
}
for component in getEdgeComponents(graph, s = 2) {
  writeln(component);
}

writeln("Calculating components for s = 3...");
for component in getVertexComponents(graph, s = 3) {
  writeln(component);
}
for component in getEdgeComponents(graph, s = 3) {
  writeln(component);
}
