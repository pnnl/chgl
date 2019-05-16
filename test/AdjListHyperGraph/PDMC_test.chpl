use IO;
use Sort;
use AdjListHyperGraph;
use Generation;
use Butterfly;


var graph = fromAdjacencyList("condMat.txt", " ");

var VertHigh : int;
var EdgeHigh : int;

for v in graph.getVertexDegrees() {
  VertHigh = max(VertHigh, v);
}
for e in graph.getEdgeDegrees() {
  EdgeHigh = max(EdgeHigh, e);
}

var f2 = open("../../../data/condMat/mpd_V.csv", iomode.r);
var f3 = open("../../../data/condMat/mpd_E.csv", iomode.r);
var vcoef : [0..-1] real;
var ecoef : [0..-1] real;
for each in f2.lines() {
  vcoef.push_back(each : real);
}
for each in f3.lines() {
  ecoef.push_back(each : real);
}

vcoef -= graph.getVertexPerDegreeMetamorphosisCoefficients();
ecoef -= graph.getEdgePerDegreeMetamorphosisCoefficients();
writeln((min reduce vcoef) > -.0001 && (max reduce vcoef) < .0001);
writeln((min reduce ecoef) > -.0001 && (max reduce ecoef) < .0001);
