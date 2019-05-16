use AdjListHyperGraph;
use Generation;
use Butterfly;

/*
var vertexDegrees = [1.0, 1.0, 1.0, 1.0, 1.0, 2.0, 2.0, 2.0, 4.0, 5.0]: int;
var edgeDegrees = [1.0, 1.0, 1.0, 2.0, 2.0, 2.0, 3.0, 3.0]: int;
var vertexMetamorphs = [0.0, 0.513, 0.469, 0.40927, 0.37258, 0.38295, 0.34176, 0.29251, 0.28721]: real;
var edgeMetamorphs = [0.0, 0.33828, 0.29778, 0.28709, 0.27506, 0.25868, 0.24713]: real;
*/

var vertexDegrees: [1..16726] int;
var edgeDegrees: [1..22015] int;
var vertexMetamorphs: [1..116] real;
var edgeMetamorphs: [1..18] real;

var vd_file = open("../../test/visual-verification/BTER-Test/dSeq_v_list.csv", iomode.r).reader();
var ed_file = open("../../test/visual-verification/BTER-Test/dSeq_E_list.csv", iomode.r).reader();
var vm_file = open("../../test/visual-verification/BTER-Test/mpd_V.csv", iomode.r).reader();
var em_file = open("../../test/visual-verification/BTER-Test/mpd_E.csv", iomode.r).reader();

for i in 1..16726{
	vd_file.read(vertexDegrees[i]);
}
for i in 1..22015{
	ed_file.read(edgeDegrees[i]);
}
for i in 1..116{
	vm_file.read(vertexMetamorphs[i]);
}
for i in 1..18{
	em_file.read(edgeMetamorphs[i]);
}

vd_file.close();
ed_file.close();
vm_file.close();
em_file.close();

writeln("generating BTER");
var graph = generateBTER(vertexDegrees, edgeDegrees, vertexMetamorphs, edgeMetamorphs);

//var myFile = open("../../test/visual-verification/BTER-Test/GENERATED_dseq_E_list.csv", iomode.cw);
//var myWritingChannel = myFile.writer();

//var generated_ed = graph.getEdgeDegrees();

//writeln("writing generated_ed");
//for i in 1..generated_ed.size{
//	myWritingChannel.writeln(generated_ed[i]);
//}

//var generatedBTERGraph = open("./generatedBTEROutput.csv", iomode.cw);
//var writingBTER = generatedBTERGraph.writer();

//for i in 1..graph.vertices.size{
//  for j in graph.vertices[i].neighborList.id{
//    writingBTER.writeln(i,",",j);
//  }
//}

writeln(graph.getVertexButterflies().size);

writeln("done");

