
use AdjListHyperGraph;
use CommDiagnostics;
use Generation;
use Time;

/* Performance Test for ChungLu algorithm */
config const isBuffered = true;
config const dataset = "Very Small";
config const dataDirectory = "../../data/LiveJournal/";
var vertexDegreeDistributionFile = "";
var edgeDegreeDistributionFile = "";
var numVertices = 0;
var numEdges = 0;
var numInclusions = 0;

select dataset {
  when "Very Small" {
    vertexDegreeDistributionFile = "d100K.csv";
    edgeDegreeDistributionFile = "d200K.csv";
    numVertices = 100000;
    numEdges = 200000;
    numInclusions = 841088;
  }
  when "Small" {
    vertexDegreeDistributionFile = "d1M.csv";
    edgeDegreeDistributionFile = "d2M.csv";
    numVertices = 1000000;
    numEdges = 2000000;
    numInclusions = 9940947;
  }
  when "Medium" { 
    vertexDegreeDistributionFile = "d10M.csv";
    edgeDegreeDistributionFile = "d20M.csv";
    numVertices = 10000000;
    numEdges = 20000000;
    numInclusions = 114855148;
  }
  when "Large" { 
    vertexDegreeDistributionFile = "d100M.csv";
    edgeDegreeDistributionFile = "d200M.csv";
    numVertices = 100000000;
    numEdges = 200000000;
    numInclusions = 1301294319;
  }
  when "Very Large" {
    vertexDegreeDistributionFile = "d1B.csv";
    edgeDegreeDistributionFile = "d2B.csv";
    numVertices = 1000000000;
    numEdges = 2000000000;
    numInclusions = 14548044386;
  }
  otherwise do halt("Need a size: 'Very Small, Small, Medium, Large, Very Large'");
}

config const profileCommunications = false;
config const profileVerboseCommunications = false;

// Read in ChungLu degree distributions...
var vDegF = open(dataDirectory + vertexDegreeDistributionFile, iomode.r).reader();
var eDegF = open(dataDirectory + edgeDegreeDistributionFile, iomode.r).reader();
var vDegSeq : [0..-1] int;
var eDegSeq : [0..-1] int;

var deg = 1;
while true {
  var tmp : int;
  var retval = vDegF.read(tmp);
  if retval == false then break;
  for 1..tmp do vDegSeq.push_back(deg);
  deg += 1;
}

deg = 1;
while true {
  var tmp : int;
  var retval = eDegF.read(tmp);
  if retval == false then break;
  for 1..tmp do eDegSeq.push_back(deg);
  deg += 1;
}

/*
var dvsSpace = {vDegSeq.domain.low..vDegSeq.domain.high};
var dvsDom = dvsSpace dmapped Block(boundingBox = dvsSpace);
var desSpace = {eDegSeq.domain.low..eDegSeq.domain.high};
var desDom = desSpace dmapped Block(boundingBox = desSpace);
var dvs : [dvsDom] int = vDegSeq;
var des : [desDom] int = eDegSeq;
*/

if profileCommunications then startCommDiagnostics();
if profileVerboseCommunications then startVerboseComm();

var graph = new AdjListHyperGraph(numVertices, numEdges, new Cyclic(startIdx=0, targetLocales=Locales));
var timer = new Timer();
timer.start();
if numLocales == 1 || isBuffered then generateChungLu(graph, vDegSeq, eDegSeq, numInclusions);
else {
  var vertexProbabilityTable = + scan (vDegSeq / (+ reduce vDegSeq):real);
  var edgeProbabilityTable = + scan (eDegSeq / (+ reduce eDegSeq):real);
  const verticesDomain = graph.verticesDomain;
  const edgesDomain = graph.edgesDomain;
  const inclusionsToAdd = numInclusions;
  // Perform work evenly across all locales
  coforall loc in Locales with (in graph) do on loc {
    const vpt = vertexProbabilityTable;
    const ept = edgeProbabilityTable;
    const perLocInclusions = inclusionsToAdd / numLocales + (if here.id == 0 then inclusionsToAdd % numLocales else 0);
    sync coforall tid in 0..#here.maxTaskPar with (in graph) {
      // Perform work evenly across all tasks
      var perTaskInclusions = perLocInclusions / here.maxTaskPar + (if tid == 0 then perLocInclusions % here.maxTaskPar else 0);
      var _randStream = new RandomStream(int, GenerationSeedOffset + here.id * here.maxTaskPar + tid);
      var randStream = new RandomStream(real, _randStream.getNext());
      for 1..perTaskInclusions {
        var vertex = getRandomElement(verticesDomain, vpt, randStream.getNext());
        var edge = getRandomElement(edgesDomain, ept, randStream.getNext());
        graph.addInclusion(vertex, edge);
      }
    }
  }
}
timer.stop();

writeln("Time:", timer.elapsed());
writeln("Nodes:", numLocales);
writeln("NumVertices: ", numVertices);
writeln("NumEdges: ", numEdges);
writeln("NumInclusions: ", numInclusions);
writeln("ActualInclusions: ", graph.getInclusions());
writeln("Contention:", Debug.contentionCnt);
writeln("maxTaskPar:", here.maxTaskPar);

if profileCommunications then writeln(getCommDiagnostics());
