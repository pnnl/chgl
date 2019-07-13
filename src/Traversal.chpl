/*
  Requires implementation of termination detection first. Need to have a generic visitor pattern using
  both a breadth first and depth first search. After this is done, can implement the components code.

  NOTE: An unrolled linked list offered a full order of magnitude speedup!
*/

use LinkedLists;
use AdjListHyperGraph;
use UnrolledLinkedList;



iter vertexBFS(graph, v : graph._value.vDescType, s=1) : graph._value.vDescType {
  var explored : domain(int);
  var queue = new UnrolledLinkedList(int, 1024);
  queue.append(v.id);
  while queue.size != 0 {
    var currV : int; 
    assert(queue.remove(currV));
    if explored.contains(currV) then continue;
    explored += currV;
    if v.id != currV then yield graph.toVertex(currV); 
    var neighbors = forall vv in graph.walk(graph.toVertex(currV), s) do vv.id;
    for neighbor in neighbors do queue.append(neighbor);
  }
}

iter edgeBFS(graph, e : graph._value.eDescType, s=1) : graph._value.eDescType {
  var explored : domain(int);
  var queue = new UnrolledLinkedList(int, 1024);
  queue.append(e.id);
  while queue.size != 0 {
    var currE : int; 
    assert(queue.remove(currE));
    if explored.contains(currE) then continue;
    explored += currE;
    if e.id != currE then yield graph.toEdge(currE);
    var neighbors = forall ee in graph.walk(graph.toEdge(currE), s, isImmutable=true) do ee.id;
    for neighbor in neighbors do queue.append(neighbor);
  }
}
