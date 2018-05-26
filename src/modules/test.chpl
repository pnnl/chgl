use AdjListHyperGraph;
use Generation;

/*
var vertexDegrees = [1.0, 1.0, 1.0, 1.0, 1.0, 2.0, 2.0, 2.0, 4.0, 5.0]: int;
var edgeDegrees = [1.0, 1.0, 1.0, 2.0, 2.0, 2.0, 3.0, 3.0]: int;
var vertexMetamorphs = [0.0, 0.513, 0.469, 0.40927, 0.37258, 0.38295, 0.34176, 0.29251, 0.28721]: real;
var edgeMetamorphs = [0.0, 0.33828, 0.29778, 0.28709, 0.27506, 0.25868, 0.24713]: real;
*/

var vertexDegrees: [1..116] int;
var edgeDegrees: [1..18] int;
var vertexMetamorphs: [1..116] real;
var edgeMetamorphs: [1..18] real;

var vd_file = open("./BTER_Test/dd_V.csv", iomode.r).reader();
var ed_file = open("./BTER_Test/dd_E.csv", iomode.r).reader();
var vm_file = open("./BTER_Test/mpd_V.csv", iomode.r).reader();
var em_file = open("./BTER_Test/mpd_E.csv", iomode.r).reader();

for i in 1..116{
	vd_file.read(vertexDegrees[i]);
	vm_file.read(vertexMetamorphs[i]);
}
for i in 1..18{
	ed_file.read(edgeDegrees[i]);
	em_file.read(edgeMetamorphs[i]);
}

vd_file.close();
ed_file.close();
vm_file.close();
em_file.close();

var graph = generateBTER(vertexDegrees, edgeDegrees, vertexMetamorphs, edgeMetamorphs);

writeln(graph.getEdgeDegrees());

writeln("done");
