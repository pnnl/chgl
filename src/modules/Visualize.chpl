use AdjListHyperGraph;

/*
  Exports graph in GraphViz DOT format
*/
proc visualize(graph, fileName = "out.dot") throws {
  var f = open(fileName, iomode.cw).writer();
  f.writeln("strict graph {");
  
  // For each vertex, label it "u" + v.id
  for v in graph.getVertices() {
    f.write("\tu" + v.id);
    // For each neighboring edge, label it "v" + e.id
    if graph.numNeighbors(v) != 0 {
      f.write(" -- {");

      for e in graph.getNeighbors(v) {
        f.write(" v", e.id);
      }
      f.writeln(" }");
    }
  }
  for e in graph.getEdges() {
    if graph.numNeighbors(e) == 0 {
      f.writeln("\tv", e.id);
    }
  }

  f.writeln("}");
  f.close();
}

proc main() {
  var g = new AdjListHyperGraph(2,3);
  g.addInclusion(0,0);
  g.addInclusion(1,0);
  g.addInclusion(1,1);
  g.addInclusion(0,1);
  visualize(g);
}
