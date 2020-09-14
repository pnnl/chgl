use AdjListHyperGraphs;
use Metrics;

var graph = new AdjListHyperGraph(9, 10);

graph.addInclusion(0, 0);
graph.addInclusion(1, 0);
graph.addInclusion(2, 0);
graph.addInclusion(0, 1);
graph.addInclusion(1, 1);
graph.addInclusion(0, 2);
graph.addInclusion(2, 2);
graph.addInclusion(1, 3);
graph.addInclusion(2, 3);
graph.addInclusion(2, 4);
graph.addInclusion(3, 4);
graph.addInclusion(3, 5);
graph.addInclusion(4, 5);

graph.addInclusion(6, 6);
graph.addInclusion(6, 7);
graph.addInclusion(7, 7);
graph.addInclusion(8, 7);
graph.addInclusion(8, 8);
graph.addInclusion(7, 9);
graph.addInclusion(8, 9);

for s in 1..3 {
    var componentMappings = getEdgeComponentMappings(graph, s);
    writeln("Components for s=", s);
    for (ix, componentId) in zip(componentMappings.domain, componentMappings) {
        writeln(graph.toEdge(ix), " -> ", componentId);
    }
}
