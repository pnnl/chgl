use CHGL;

config const numVertices = 1024;
config const numEdges = 1024;
var graph = new Graph(numVertices, numEdges);
forall (i,j) in zip(0..#numVertices by 2, 1..#numEdges by 2) {
  graph.addEdge(i,j);
}
graph.flush();
forall (v1,v2) in graph.getEdges() {

}

writeln("SUCCESS!");
