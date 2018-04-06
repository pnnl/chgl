use AdjListHyperGraph;

var graph = new AdjListHyperGraph();

writeln(graph);

writeln("graph.resize_edges(3)");
graph.resize_edges(3);
writeln(graph);

writeln("graph.resize_vertices(3);");
graph.resize_vertices(3);
writeln(graph);

writeln("graph.resize_edges(4);");
graph.resize_edges(4);
writeln(graph);

writeln("graph.resize_vertices(4);");
graph.resize_vertices(4);
writeln(graph);

writeln("graph.resize_edges(2);");
graph.resize_edges(2);
writeln(graph);

writeln("graph.resize_vertices(2);");
graph.resize_vertices(2);
writeln(graph);

writeln("graph.resize_edges(1);");
graph.resize_edges(1);
writeln(graph);

writeln("graph.resize_vertices(1);");
graph.resize_vertices(1);
writeln(graph);

writeln("graph.resize_edges(0);");
graph.resize_edges(0);
writeln(graph);

writeln("graph.resize_vertices(0);");
graph.resize_vertices(0);
writeln(graph);
