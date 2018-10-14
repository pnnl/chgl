/*
  Requires implementation of termination detection first. Need to have a generic visitor pattern using
  both a breadth first and depth first search. After this is done, can implement the components code.
*/

use List;
use AdjListHyperGraph;

proc list.contains(elt : eltType) {
  for e in this do if e == elt then return true;
  return false;
}

iter vertexBFS(graph, v : graph._value.vDescType, s=1) : graph._value.vDescType {
  var explored = new list(v.type);
  var queue = new list(v.type);
  queue.push_back(v);
  while queue.size != 0 {
    var currV = queue.pop_front();
    if explored.contains(currV) then continue;
    explored.push_back(currV);
    if v != currV then yield currV;
    for vv in graph.walk(currV, s) {
      queue.push_back(vv);
    }
  }
}

iter edgeBFS(graph, e : graph._value.eDescType, s=1) : graph._value.eDescType {
  var explored = new list(e.type);
  var queue = new list(e.type);
  queue.push_back(e);
  while queue.size != 0 {
    var currE = queue.pop_front();
    if explored.contains(currE) then continue;
    explored.push_back(currE);
    if e != currE then yield currE;
    for ee in graph.walk(currE, s) {
      queue.push_back(ee);
    }
  }
}
