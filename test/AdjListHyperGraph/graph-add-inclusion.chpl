use AdjListHyperGraphs;
use CyclicDist;

var graph = new AdjListHyperGraph(10,10);

graph.addInclusion(0,1);
graph.addInclusion(graph.toVertex(8), graph.toEdge(9));

writeln(graph);
