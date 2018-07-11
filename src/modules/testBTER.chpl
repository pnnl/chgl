use AdjListHyperGraph;
use Generation;
use Butterfly;

/*
var vertexDegrees = [1.0, 1.0, 1.0, 1.0, 1.0, 2.0, 2.0, 2.0, 4.0, 5.0]: int;
var edgeDegrees = [1.0, 1.0, 1.0, 2.0, 2.0, 2.0, 3.0, 3.0]: int;
var vertexMetamorphs = [0.0, 0.513, 0.469, 0.40927, 0.37258, 0.38295, 0.34176, 0.29251, 0.28721]: real;
var edgeMetamorphs = [0.0, 0.33828, 0.29778, 0.28709, 0.27506, 0.25868, 0.24713]: real;
*/

var vertexDegrees: [0..16725] int;
var edgeDegrees: [0..22014] int;
var vertexMetamorphs: [0..115] real;
var edgeMetamorphs: [0..17] real;

var vd_file = open("../../data/condMat/dSeq_v_list.csv", iomode.r).reader();
var ed_file = open("../../data/condMat/dSeq_E_list.csv", iomode.r).reader();
var vm_file = open("../../data/condMat/mpd_V.csv", iomode.r).reader();
var em_file = open("../../data/condMat/mpd_E.csv", iomode.r).reader();

for i in 0..16725{
	vd_file.read(vertexDegrees[i]);
}
for i in 0..22014{
	ed_file.read(edgeDegrees[i]);
}
for i in 0..115{
	vm_file.read(vertexMetamorphs[i]);
}
for i in 0..17{
	em_file.read(edgeMetamorphs[i]);
}

vd_file.close();
ed_file.close();
vm_file.close();
em_file.close();

writeln("generating BTER w/o coupon collector...");
var graph = generateBTER(vertexDegrees, edgeDegrees, vertexMetamorphs, edgeMetamorphs);
writeln((+ reduce graph.getVertexButterflies()) / 2);
//writeln((+ reduce graph.getVertexCaterpillars()) / 2);
writeln("done");

//var outfile = open("out.csv", iomode.cw).writer();
//forall v in graph.getVertices() {
//  forall e in graph.getNeighbors(v) {
//    outfile.writeln(v.id, ", ", e.id);
//  }
//}
//outfile.close();
