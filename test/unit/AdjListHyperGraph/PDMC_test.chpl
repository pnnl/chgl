use IO;
use Sort;
use AdjListHyperGraph;
use Generation;


var f = open("condMat.txt", iomode.r);
var r = f.reader();

var vertices : [0..-1] int;
var edges : [0..-1] int;

for each in f.lines() {
  var (v,e) : 2 * int;
  var line = each.strip("\n");
  var split = line.split(" ");
  if line == "" then continue;
  vertices.push_back(split[1] : int);
  edges.push_back(split[2] : int);
}

var numEdges : int;
var numVertices : int;

for (v,e) in zip(vertices,edges) {
  numVertices = max(numVertices, v);
  numEdges = max(numEdges, e);
}

var graph = new AdjListHyperGraph({1..numVertices},{1..numEdges});
for (v,e) in zip(vertices,edges) {
  graph.addInclusion(v,e);
}

var VertHigh : int;
var EdgeHigh : int;

for v in graph.getVertexDegrees() {
  VertHigh = max(VertHigh, v);
}
for e in graph.getEdgeDegrees() {
  EdgeHigh = max(EdgeHigh, e);
}

// Everthing above has been taken from the test files on gitlab

var VertPDMC : [0..VertHigh] real;
var EdgePDMC : [0..EdgeHigh] real;
var VertArr : [graph.getVertexDegrees().domain] real;
var EdgeArr : [graph.getEdgeDegrees().domain] real;

var VertB : [VertArr.domain] real = graph.getVertexButterflies() : real;
var VertC : [VertArr.domain] real = graph.getVertexCaterpillars() : real;

//this is to allow for a graph.getVertexButterflies()/graph.getVertexCaterpillars() while preventing nan values
forall i in VertB.domain{
  if VertC[i] > 0 && VertB[i] > 0{
    VertArr[i] = VertB[i]/VertC[i];
  }
}

var EdgeB : [EdgeArr.domain] real = graph.getEdgeButterflies() : real;
var EdgeC : [EdgeArr.domain] real = graph.getEdgeCaterpillars() : real;

forall i in EdgeB.domain{
  if EdgeC[i] > 0 && EdgeB[i] > 0{
    EdgeArr[i] = EdgeB[i]/EdgeC[i];
  }
}

// nested loops needed to get the PDMC for Vertices
// Will work on Edge PDMC after Vertex PDMC is working
forall d in 1..VertPDMC.size { //for each degree available
  var arr : [0..-1] real;
  for (v,i) in zip(graph.getVertexDegrees(),graph.getVertexDegrees().domain) {
    var temparray : [0..-1] real;
    if v == d{ //if our vertex degree == the degree we are looking at
      for n in graph.vertices[i].neighborList { // get the neighbors
        temparray.push_back(EdgeArr[n.id]); // add the MC for each neighbor to the list
      }
    }
    if temparray.size >= 1{
      arr.push_back(+ reduce temparray/temparray.size); // get the average of the MC value
    }
  }
  if arr.size >= 1{
    VertPDMC[d] = + reduce arr/ arr.size; // get the average of all included averages
  }
}

// TODO: Edge PDMC

for each in VertPDMC{
writeln(each);
}
