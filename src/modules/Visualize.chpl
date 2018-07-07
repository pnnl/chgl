use AdjListHyperGraph;
use Sort;

/*
  Exports graph in GraphViz DOT format
*/
proc visualize(graph, fileName = "out.dot") throws {
  var vertexVisited : [graph.verticesDomain] bool;
  var edgeVisited : [graph.edgesDomain] bool;
  var f = open(fileName, iomode.cw).writer();

  proc visitVertex(v, ref str) {
    // Mark this vertex, and then write out neighbors
    if vertexVisited[v.id] then return;
    vertexVisited[v.id] = true;
    str += "\t\tu" + v.id; 
    writeln("Processing u", v.id);
    if graph.numNeighbors(v) != 0 {
      str += " -- {"; 
      for e in graph.getNeighbors(v) {
        str += " v" + e.id;
      }
      str += " }\n";
    } else {
      str += "\n";
    }
    
    // Visit neighbors
    for e in graph.getNeighbors(v) {
      visitEdge(e, str);
    }
  }
 
  proc visitEdge(e, ref str) {
    // Mark this edge, and then write out neighbors
    if edgeVisited[e.id] then return;
    edgeVisited[e.id] = true;
    writeln("Processing v", e.id);
    str += "\t\tv" + e.id; 
    if graph.numNeighbors(e) != 0 {
      str += " -- {"; 
      for v in graph.getNeighbors(e) {
        str += " u" + v.id;
      }
      str += " }\n";
    } else {
      str += "\n";
    }
    
    // Visit neighbors
    for v in graph.getNeighbors(e) {
      visitVertex(v, str);
    }
  }
  
  // Color vertices red, hyperedges blue
  f.writeln("strict graph {");
  for v in graph.getVertices() {
    f.writeln("\tu", v.id, " [color=red]");
  }
  for e in graph.getEdges() {
    f.writeln("\tv", e.id, " [color=blue]");
  }

  var subgraphStr = "";
  var firstVertex = true;
  for v in graph.getVertices() {
    if !vertexVisited[v.id] {
      f.writeln("\tsubgraph {");
    } else if !firstVertex {
      writeln("subgraphStr=", subgraphStr);
      // Sort the string lines
      var arr = subgraphStr.split("\n");
      sort(arr);
      f.writeln(for a in arr do a + "\n");
      subgraphStr = "";
      f.writeln("\t}");
    } else {
      firstVertex = false;
    }
    visitVertex(v, subgraphStr);
  }
  
  writeln("subgraphStr=", subgraphStr);
  // Sort the string lines
  var arr = subgraphStr.split("\n");
  sort(arr);
  f.writeln(for a in arr do a + "\n");
  subgraphStr = "";
  f.writeln("\t}");

  var firstEdge = true;
  for e in graph.getEdges() {
    if !edgeVisited[e.id] {
      writeln("Found isolated edge: ", e.id);
      f.writeln("\tsubgraph {\n\t\tv", e.id, "\n\t}");
      edgeVisited[e.id] = true;
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
