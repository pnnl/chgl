/*
  Requires implementation of termination detection first. Need to have a generic visitor pattern using
  both a breadth first and depth first search. After this is done, can implement the components code.
*/

use CHGL;



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

iter vertexBFS(graph, v : graph._value.vDescType, s=1, param tag : iterKind) : graph._value.vDescType where tag == iterKind.standalone {
  var visited : [graph.verticesDomain] atomic bool;
  var td = new TerminationDetector(1);
  var wq = new WorkQueue(int, 1024 * 1024, new DuplicateCoalescer(int, -1));
  wq.addWork(v.id, graph.getLocale(v));
  forall v in doWorkLoop(wq, td) {
    if v != -1 && visited[v].testAndSet() == false {
      yield graph.toVertex(v);
      forall vv in graph.walk(graph.toVertex(v), s=1, isImmutable=true) {
        td.started(1);
        wq.addWork(vv.id, graph.getLocale(vv));
      }
    }
    td.finished(1);
  }
  td.destroy();
  wq.destroy();
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

iter edgeBFS(graph, e : graph._value.eDescType, s=1, param tag : iterKind) : graph._value.eDescType where tag == iterKind.standalone {  
  var visited : [graph.edgesDomain] atomic bool;
  var td = new TerminationDetector(1);
  var wq = new WorkQueue(int, 1024 * 1024, new DuplicateCoalescer(int, -1));
  wq.addWork(e.id, graph.getLocale(e));
  forall e in doWorkLoop(wq, td) {
    if e != -1 && visited[e].testAndSet() == false {
      yield graph.toEdge(e);
      forall ee in graph.walk(graph.toEdge(e), s=1, isImmutable=true) {
        td.started(1);
        wq.addWork(ee.id, graph.getLocale(ee));
      }
    }
    td.finished(1);
  }
  td.destroy();
  wq.destroy();
}
