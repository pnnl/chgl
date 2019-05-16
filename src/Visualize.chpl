use AdjListHyperGraph;
use Generation;
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
    if graph.degree(v) != 0 {
      str += " -- {"; 
      for e in graph.incidence(v) {
        str += " v" + e.id;
      }
      str += " }\n";
    } else {
      writeln("Found isolated vertex: ", v.id);
      str += "\n";
    }
    
    // Visit neighbors
    for e in graph.incidence(v) {
      visitEdge(e, str);
    }
  }
 
  proc visitEdge(e, ref str) {
    // Mark this edge, and then write out neighbors
    if edgeVisited[e.id] then return;
    edgeVisited[e.id] = true;
    str += "\t\tv" + e.id; 
    if graph.degree(e) != 0 {
      str += " -- {"; 
      for v in graph.incidence(e) {
        str += " u" + v.id;
      }
      str += " }\n";
    } else {
      str += "\n";
    }
    
    // Visit neighbors
    for v in graph.incidence(e) {
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
  var clusterNum = 1;
  var insideSubgraph = false;
  for v in graph.getVertices() {
    if !vertexVisited[v.id] {
      if insideSubgraph {
        // Sort the string lines
        var arr = subgraphStr.split("\n");
        sort(arr);
        f.writeln(for a in arr do if a != "" then a + "\n");
        subgraphStr = "";
        f.writeln("\t}");
        insideSubgraph = false;
      }
      f.writeln("\tsubgraph cluster_", clusterNum, " {");
      clusterNum += 1;
      insideSubgraph = true;
    } else if insideSubgraph {
      // Sort the string lines
      var arr = subgraphStr.split("\n");
      sort(arr);
      f.writeln(for a in arr do if a != "" then a + "\n");
      subgraphStr = "";
      f.writeln("\t}");
      insideSubgraph = false;
    } 
    visitVertex(v, subgraphStr);
  }
  
  if insideSubgraph {
    // Sort the string lines
    var arr = subgraphStr.split("\n");
    sort(arr);
    f.writeln(for a in arr do if a != "" then a + "\n");
    subgraphStr = "";
    f.writeln("\t}");
    insideSubgraph = false;
  }

  for e in graph.getEdges() {
    if !edgeVisited[e.id] {
      writeln("Found isolated edge: ", e.id);
      f.writeln("\tsubgraph cluster_", clusterNum, " {\n\t\tv", e.id, "\n\t}");
      clusterNum += 1;
      edgeVisited[e.id] = true;
    }
  }
  
  f.writeln("}");
  f.close();
}

proc main() {
  var g = new AdjListHyperGraph(10,10);
  generateErdosRenyiSMP(g, 0.5, g.verticesDomain[0..4], g.edgesDomain[0..4]);
  generateErdosRenyiSMP(g, 0.5, g.verticesDomain[5..9], g.edgesDomain[5..9]);
  visualize(g);
}
