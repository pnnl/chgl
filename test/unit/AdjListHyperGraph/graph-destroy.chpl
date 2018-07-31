use AdjListHyperGraph;

var graph = new AdjListHyperGraph(1,1);
graph.destroy();
assert(graph.pid == -1, "Graph has non-nil pid!");
