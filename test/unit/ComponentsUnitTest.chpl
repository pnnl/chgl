use AdjListHyperGraph;
use Components;

var graph = new AdjListHyperGraph(numVertices = 10, numEdges = 10);

var count = graph.countComponents();
writeln(count);
