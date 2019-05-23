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
use Time;
use Utilities;

config const dataset = "../data/karate.mtx_csr.bin";

beginProfile("TriangleCounting-profile");
var timer = new Timer();
timer.start();
var graph = binToGraph(dataset);
timer.stop();
writeln("Graph generation for ", dataset, " took ", timer.elapsed(), "s");
timer.clear();
writeln("|V| = ", graph.numVertices, " and |E| = ", graph.numEdges);

timer.start();
graph.simplify();
timer.stop();
writeln("Simplified graph in ", timer.elapsed(), "s");
timer.clear();

timer.start();
graph.validateCache();
timer.stop();
writeln("Generated cache in ", timer.elapsed(), "s");
timer.clear();

timer.start();
var numTriangles : int;
forall v in graph.getVertices() with (+ reduce numTriangles) {
  for u in graph.neighbors(v) {
    if v.id > u.id then numTriangles += graph.intersectionSize(v,u);
  }
}
timer.stop();
writeln("# of Triangles = ", numTriangles / 3, " found in ", timer.elapsed(), "s");
endProfile();
visualize(graph);
