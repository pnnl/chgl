use AdjListHyperGraph;
use CyclicDist;
use BlockDist;

const vertex_domain = {1..10} dmapped Cyclic(startIdx=0);
const edge_domain = {1..10} dmapped Cyclic(startIdx=0);

var graph = new AdjListHyperGraph();
writeln(graph);
var graph1 = new AdjListHyperGraph(10, 10);
writeln(graph1);
var graph2 = new AdjListHyperGraph(map = new Cyclic(startIdx=0));
writeln(graph2);
var graph3 = new AdjListHyperGraph(map = new Block(boundingBox={1..1}));
writeln(graph3);
var graph4 = new AdjListHyperGraph(10, 10, new Block(boundingBox={1..1}));
writeln(graph4);
var graph5 = new AdjListHyperGraph(10, map = new Block(boundingBox={1..1}));
writeln(graph5);
var graph6 = new AdjListHyperGraph(num_edges = 10, map = new Block(boundingBox={1..1}));
writeln(graph6);
