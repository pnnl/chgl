/*
  Algorithm:
  var numTriangles : int;
  forall v in graph.getVertices() with (+ reduce numTriangles) {
    for u in graph.neighbors(v) {
      for w in graph.intersection(v,u) {
        numTriangles += 1;
      }
    }
  }
*/

use Graph;
use CyclicDist;
use Random;
use BinReader;
use Visualize;

config const dataset = "../data/karate.mtx_csr.bin";

var graph = binToGraph(dataset);
writeln("|V| = ", graph.numVertices, " and |E| = ", graph.numEdges);

var numTriangles : int;
forall v in graph.getVertices() with (+ reduce numTriangles) {
  for u in graph.neighbors(v) {
    if v.id > u.id then numTriangles += graph.intersectionSize(v,u);
  }
}
writeln("# of Triangles = ", numTriangles / 3);
visualize(graph);
