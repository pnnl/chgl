use AdjListHyperGraph;
use Generation;
use Butterfly;
use Time;

config const dataPath = "../../data";

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

var timer : Timer;
timer.start();
var graph = generateBTER(vertexDegrees, edgeDegrees, vertexMetamorphs, edgeMetamorphs);
timer.stop();
writeln("Time: ", timer.elapsed());
