use AdjListHyperGraph;

const vertex_domain = {1..10} dmapped Cyclic(startIdx=0);
const edge_domain = {1..10} dmapped Cyclic(startIdx=0);
var graph = new AdjListHyperGraph(vertices_dom = vertex_domain, edges_dom = edge_domain);

for i in 1 .. 10 {
  for j in i .. 10 {
    graph.addInclusion(i, j);
  }
}

var vertDegrees = graph.getVertexDegrees();
var edgeDegrees = graph.getEdgeDegrees();
writeln(vertDegrees);
writeln(edgeDegrees);
