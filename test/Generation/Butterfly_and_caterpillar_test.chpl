use Math;
use AdjListHyperGraphs;
use Butterfly;

// with this test there are a possiblility of 16 edges total being generated
var graph = new AdjListHyperGraph(5,4);
graph.addInclusion(0,0);
graph.addInclusion(0,1);
graph.addInclusion(1,0);
graph.addInclusion(1,1);
graph.addInclusion(2,0);
graph.addInclusion(2,1);
graph.addInclusion(2,2);
graph.addInclusion(2,3);
graph.addInclusion(3,2);
graph.addInclusion(3,3);
graph.addInclusion(4,3);
var val = 0;
if getVertexButterflies(graph).equals([2,2,3,1,0]){
  val += 1;
} else writeln("Bad Vertex Butterflies: ", getVertexButterflies(graph), " expected: ", [2,2,3,1,0]);
if getVertexCaterpillars(graph).equals([8,8,14,6,4]){
  val += 1;
} else writeln("Bad Vertex Caterpillars: ", getVertexCaterpillars(graph), " expected: ", [8,8,14,6,4]);
if getEdgeButterflies(graph).equals([3,3,1,1]){
  val += 1;
} else writeln("Bad Edge Butterflies: ", getEdgeButterflies(graph), " expected: ", [3,3,1,1]);
if getEdgeCaterpillars(graph).equals([10,10,8,8]){
  val += 1;
} else writeln("Bad Edge Caterpillars: ", getEdgeCaterpillars(graph), " expected: ", [10,10,8,8]);
writeln(val == 4);
