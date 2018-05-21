use AdjListHyperGraph;
use CyclicDist;

var graph = new AdjListHyperGraph(10,10);

graph.add_inclusion(0,1);
graph.add_inclusion(graph.toVertex(8), graph.toEdge(9));

writeln(graph);
