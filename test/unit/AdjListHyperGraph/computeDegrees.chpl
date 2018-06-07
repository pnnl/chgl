use AdjListHyperGraph;

const numVertices = 10;
const numEdges = 10;
var graph = new AdjListHyperGraph(numVertices, numEdges);

for i in graph.verticesDomain {
  for j in graph.edgesDomain {
    graph.addInclusion(i, j);
  }
}

var vertDegrees = graph.getVertexDegrees();
var edgeDegrees = graph.getEdgeDegrees();
writeln(vertDegrees);
writeln(edgeDegrees);
