use Math;
use AdjListHyperGraph;
use Random;
use Generation;

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
if graph.getVertexButterflies().equals([2,2,3,1,0]){
  val += 1;
}
if graph.getVertexCaterpillars().equals([8,8,14,6,4]){
  val += 1;
}
if graph.getEdgeButterflies().equals([3,3,1,1]){
  val += 1;
}
if graph.getEdgeCaterpillars().equals([10,10,8,8]){
  val += 1;
}
writeln(val == 4);