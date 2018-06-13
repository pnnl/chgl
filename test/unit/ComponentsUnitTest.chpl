use AdjListHyperGraph;
use Components;

var graph = new AdjListHyperGraph(numVertices = 10, numEdges = 10);
for v in graph.getVertices() do for e in graph.getEdges() do graph.addInclusion(v,e);

var count = graph.countComponents();
writeln(count);
