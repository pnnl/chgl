use AdjListHyperGraph;
use Components;

var graph = new AdjListHyperGraph(numVertices = 4, numEdges = 3);
// Create a butterfly... (v0 -> e0), (e0 -> v2), (v2 -> e2), (e2 -> v0)
graph.addInclusion(0,0);
graph.addInclusion(2,0);
graph.addInclusion(2,2);

// Create a line... (v1 -> e1)
graph.addInclusion(1,1);

// Leave v3 as isolated... Should have 3 components
var count = graph.countComponents();
writeln(count);
