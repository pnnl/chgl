use AdjListHyperGraph;

const numVertices = 10;
const numEdges = 10;
var graph = new AdjListHyperGraph(numVertices, numEdges);

for i in 1 .. 10 {
  for j in i .. 10 {
    graph.addInclusion(i, j);
  }
}

var vertDegrees = graph.getVertexDegrees();
var edgeDegrees = graph.getEdgeDegrees();
writeln(vertDegrees);
writeln(edgeDegrees);
