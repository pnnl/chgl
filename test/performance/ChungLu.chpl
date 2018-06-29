
use AdjListHyperGraph;
use CommDiagnostics;
use Generation;
use Time;

/* Performance Test for ChungLu algorithm */
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

if profileCommunications then startCommDiagnostics();
if profileVerboseCommunications then startVerboseComm();

var graph = new AdjListHyperGraph(numVertices, numEdges, new Cyclic(startIdx=0, targetLocales=Locales));
var timer = new Timer();
timer.start();
if numLocales == 1 then generateChungLuSMP(graph, vDegSeq.domain, eDegSeq.domain, vDegSeq, eDegSeq, numInclusions);
else generateChungLu(graph, vDegSeq.domain, eDegSeq.domain, vDegSeq, eDegSeq, numInclusions);
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
