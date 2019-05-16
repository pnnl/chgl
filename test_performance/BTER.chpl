use AdjListHyperGraph;
use CommDiagnostics;
use VisualDebug;
use Generation;
use Time;

/* Performance Test for BTER algorithm */
config const dataset = "VerySmall";
config const dataDirectory = "../../data/LiveJournal/";
config const doCommDiagnostics = false;
config const doVerboseComm = false;
config const doVisualDebug = false;
var vertexDegreeDistributionFile = "";
var edgeDegreeDistributionFile = "";
var vertexMetamorphosisCoefficientsFile = "";
var edgeMetamorphosisCoefficientsFile = "";
var numVertices = 0;
var numEdges = 0;
var numInclusions = 0;

select dataset {
  when "VerySmall" {
    vertexDegreeDistributionFile = "d100K.csv";
    edgeDegreeDistributionFile = "d200K.csv";
    vertexMetamorphosisCoefficientsFile = "m100K.csv";
    edgeMetamorphosisCoefficientsFile = "m200K.csv";
    numVertices = 100000;
    numEdges = 200000;
    numInclusions = 841088;
  }
  when "Small" {
    vertexDegreeDistributionFile = "d1M.csv";
    edgeDegreeDistributionFile = "d2M.csv";
    vertexMetamorphosisCoefficientsFile = "m1M.csv";
    edgeMetamorphosisCoefficientsFile = "m2M.csv";
    numVertices = 1000000;
    numEdges = 2000000;
    numInclusions = 9940947;
  }
  when "Medium" { 
    vertexDegreeDistributionFile = "d10M.csv";
    edgeDegreeDistributionFile = "d20M.csv";
    vertexMetamorphosisCoefficientsFile = "m10M.csv";
    edgeMetamorphosisCoefficientsFile = "m20M.csv";
    numVertices = 10000000;
    numEdges = 20000000;
    numInclusions = 114855148;
  }
  when "Large" { 
    vertexDegreeDistributionFile = "d100M.csv";
    edgeDegreeDistributionFile = "d200M.csv";
    vertexMetamorphosisCoefficientsFile = "m100M.csv";
    edgeMetamorphosisCoefficientsFile = "m200M.csv";
    numVertices = 100000000;
    numEdges = 200000000;
    numInclusions = 1301294319;
  }
  when "VeryLarge" {
    vertexDegreeDistributionFile = "d1B.csv";
    edgeDegreeDistributionFile = "d2B.csv";
    vertexMetamorphosisCoefficientsFile = "m1B.csv";
    edgeMetamorphosisCoefficientsFile = "m2B.csv";
    numVertices = 1000000000;
    numEdges = 2000000000;
    numInclusions = 14548044386;
  }
  otherwise do halt("Need a size: 'Very Small, Small, Medium, Large, Very Large'");
}

// TODO: Make not naive... Will crash when reading large dataset
// Read in ChungLu degree distributions...
var vDegF = open(dataDirectory + vertexDegreeDistributionFile, iomode.r).reader();
var eDegF = open(dataDirectory + edgeDegreeDistributionFile, iomode.r).reader();
var vMetaF = open(dataDirectory + vertexMetamorphosisCoefficientsFile, iomode.r).reader();
var eMetaF = open(dataDirectory + edgeMetamorphosisCoefficientsFile, iomode.r).reader();
var vDegSeq : [0..-1] int;
var eDegSeq : [0..-1] int;
var vMetaCoef : [0..-1] real;
var eMetaCoef : [0..-1] real;

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

while true {
  var tmp : real;
  var retval = vMetaF.read(tmp);
  if retval == false then break;
  vMetaCoef.push_back(tmp);
}

while true {
  var tmp : real;
  var retval = eMetaF.read(tmp);
  if retval == false then break;
  eMetaCoef.push_back(tmp);
}

if doCommDiagnostics then startCommDiagnostics();
if doVerboseComm then startVerboseComm();
if doVisualDebug then startVdebug("ChungLu-VisualDebug");

if doVisualDebug then tagVdebug("Initialization");
if doVisualDebug then tagVdebug("Generation");
var timer = new Timer();
timer.start();
var graph = generateBTER(vDegSeq, eDegSeq, vMetaCoef, eMetaCoef);
timer.stop();

if doVisualDebug then stopVdebug();
if doVerboseComm then stopVerboseComm();
if doCommDiagnostics then writeln(getCommDiagnostics());

writeln("Time:", timer.elapsed());
writeln("Dataset:", dataset);
writeln("Nodes:", numLocales);
writeln("NumVertices: ", numVertices);
writeln("NumEdges: ", numEdges);
writeln("Inclusions: ", graph.getInclusions());
writeln("Contention:", Debug.contentionCnt);
writeln("maxTaskPar:", here.maxTaskPar);
graph.destroy();
