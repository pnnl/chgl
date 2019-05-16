use AdjListHyperGraph;
use Generation;

var vertices_degree : [0..9] int = [1.0, 1.0, 1.0, 1.0, 1.0, 2.0, 2.0, 2.0, 4.0, 5.0] : int;
var edges_degree : [0..7] int = [1.0, 1.0, 1.0, 2.0, 2.0, 2.0, 3.0, 3.0]: int;
var vertices_metamorphosis : [0..8] real = [0.0, 0.513, 0.469, 0.40927, 0.37258, 0.38295, 0.34176, 0.29251, 0.28721]: real;
var edges_metamorphosis : [0..6] real = [0.0, 0.33828, 0.29778, 0.28709, 0.27506, 0.25868, 0.24713]: real;

var graph = generateBTER(vertices_degree, edges_degree, vertices_metamorphosis, edges_metamorphosis);

writeln("numVertices = ", graph.numVertices);
writeln("numEdges = ", graph.numEdges);
writeln("Has Inclusions? ", graph.getInclusions() > 0);
