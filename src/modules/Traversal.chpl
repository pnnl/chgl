/*
  Requires implementation of termination detection first. Need to have a generic visitor pattern using
  both a breadth first and depth first search. After this is done, can implement the components code.
*/

use List;
use AdjListHyperGraph;

iter vertexBFS(graph, v : graph._value.vDescType, s=1) : graph._value.vDescType {
  var queue = new list(v.type);
  queue.push_back(v);
  while queue.size != 0 {
    var currV = queue.pop_front();
    if v != currV then yield currV;
    for vv in graph.walk(currV, s) {
      queue.push_back(vv);
    }
  }
}

iter edgeBFS(graph, e : graph._value.eDescType, s=1) : graph._value.eDescType {
  var queue = new list(e.type);
  queue.push_back(e);
  while queue.size != 0 {
    var currE = queue.pop_front();
    if e != currE then yield currE;
    for ee in graph.walk(currE, s) {
      queue.push_back(ee);
    }
  }
}
