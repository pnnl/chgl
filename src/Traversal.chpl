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
  var explored : domain(int);
  var queue = new list(int);
  queue.push_back(v.id);
  while queue.size != 0 {
    var currV = queue.pop_front();
    if explored.contains(currV) then continue;
    explored += currV;
    if v.id != currV then yield graph.toVertex(currV); 
    for vv in graph.walk(graph.toVertex(currV), s) {
      queue.push_back(vv.id);
    }
  }
}

iter edgeBFS(graph, e : graph._value.eDescType, s=1) : graph._value.eDescType {
  var explored : domain(int);
  var queue = new list(int);
  queue.push_back(e.id);
  while queue.size != 0 {
    var currE = queue.pop_front();
    if explored.contains(currE) then continue;
    explored += currE;
    if e.id != currE then yield graph.toEdge(currE);
    for ee in graph.walk(graph.toEdge(currE), s) {
      queue.push_back(ee.id);
    }
  }
}
