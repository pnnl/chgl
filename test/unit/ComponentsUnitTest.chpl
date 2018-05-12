use AdjListHyperGraph;
use Components;
use CyclicDist;

const vertex_domain = {1..10} dmapped Cyclic(startIdx=0);
const edge_domain = {1..10} dmapped Cyclic(startIdx=0);

var graph = new AdjListHyperGraph(vertices_dom = vertex_domain, edges_dom = edge_domain);

var count = countComponents(graph);
writeln(count);