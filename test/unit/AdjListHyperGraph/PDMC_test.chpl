use IO;
use Sort;
use AdjListHyperGraph;
use Butterfly;
use Generation;

var graph = fromAdjacencyList("condMat.txt", " ");
const vertexDegrees = graph.getVertexDegrees();
const edgeDegrees = graph.getEdgeDegrees();
var VertPDMC : [graph.verticesDomain] real;
var EdgePDMC : [graph.edgesDomain] real;
var VertArr : [graph.verticesDomain] real;
var EdgeArr : [graph.edgesDomain] real;
var VertB : [graph.verticesDomain] real = graph.getVertexButterflies() : real;
var VertC : [graph.verticesDomain] real = graph.getVertexCaterpillars() : real;

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
      for n in graph.getVertex(i).neighborList { // get the neighbors
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
