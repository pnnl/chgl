use AdjListHyperGraph;
use Generation;
use Math;
use Sort;

/*---SET 1---*/
//var vertex_degrees = [1.0, 1.0, 1.0, 1.0, 1.0, 2.0, 2.0, 2.0, 4.0, 5.0]: int;
//var edge_degrees = [1.0, 1.0, 1.0, 2.0, 2.0, 2.0, 3.0, 3.0]: int;
//var vertex_metamorphosis = [0.0, 0.513, 0.469, 0.40927, 0.37258, 0.38295, 0.34176, 0.29251, 0.28721]: real;
//var edge_metamorphosis = [0.0, 0.33828, 0.29778, 0.28709, 0.27506, 0.25868, 0.24713]: real;
/*---SET 1---*/

/*---SET 2---*/
var vertex_degrees: [1..16726] int;
var edge_degrees: [1..22015] int;
var vertex_metamorphosis: [1..116] real;
var edge_metamorphosis: [1..18] real;

var vd_file = open("vertex_degrees.csv", iomode.r).reader();
var ed_file = open("edge_degrees.csv", iomode.r).reader();
var vm_file = open("vertex_metamorphosis.csv", iomode.r).reader();
var em_file = open("edge_metamorphosis.csv", iomode.r).reader();

for i in 1..16726{
	vd_file.read(vertex_degrees[i]);
}
for i in 1..22015{
	ed_file.read(edge_degrees[i]);
}
for i in 1..116{
	vm_file.read(vertex_metamorphosis[i]);
}
for i in 1..18{
	em_file.read(edge_metamorphosis[i]);
}

/*---SET 2---*/

//writeln(vertex_degrees);
//writeln("next");
//writeln(edge_degrees);
//writeln("next");
//writeln(vertex_metamorphosis);
//writeln("next");
//writeln(edge_metamorphosis);

var graph = bter_hypergraph(vertex_degrees, edge_degrees, vertex_metamorphosis, edge_metamorphosis);
//writeln("next");
//for e in graph.vertices{
//	writeln(e.neighborList);
//}


writeln("done");