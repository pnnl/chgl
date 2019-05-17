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

config const numVertices = 1024;
config const numEdges = numVertices ** 2;
config const edgeProbability = 0.1;

var graph = new Graph(numVertices, numEdges, new Cyclic(startIdx=0));
forall v in graph.getVertices() with (var rng = new RandomStream(real)) {
  for u in graph.getVertices() {
    if u != v && rng.getNext() < edgeProbability then graph.addEdge(u,v);
  }
}
writeln("Generated graph with |V| = ", numVertices, " and |E| = ", numEdges);

var numTriangles : int;
forall v in graph.getVertices() with (+ reduce numTriangles) {
  for u in graph.neighbors(v) {
    for w in graph.intersection(v,u) {
      numTriangles += 1;
    }
  }
}
writeln("|V| = ", numVertices, ", |E| = ", numEdges, ", # of Triangles = ", numTriangles / 3);
