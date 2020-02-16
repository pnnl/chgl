/*Homology computation on small DNS datasets*/
/*To compile : chpl -o homology_dns --fast --cc-warnings -M../../src --dynamic --no-lifetime-checking --no-warnings homology_dns.chpl */

use CHGL; // Includes all core and utility components of CHGL
use Time; // For Timer
use Set;
use Map;
use List;
use Sort;
use Search;
use Regexp;
use FileSystem;
use BigInteger;

config const datasetDirectory = "./homology_dns_data/";
/*
  Output directory.
*/
config const outputDirectory = "tmp/";
// Maximum number of files to process.
config const numMaxFiles = max(int(64));

var files : [0..-1] string;
var vPropMap = new PropertyMap(string);
var ePropMap = new PropertyMap(string);
var wq = new WorkQueue(string, 1024);
var td = new TerminationDetector();
var t = new Timer();

proc printPropertyDistribution(propMap) : void {
  var localNumProperties : [LocaleSpace] int;
  coforall loc in Locales do on loc do localNumProperties[here.id] = propMap.numProperties();
  var globalNumProperties = + reduce localNumProperties;
  for locid in LocaleSpace {
    writeln("Locale#", locid, " has ", localNumProperties[locid], "(", localNumProperties[locid] : real / globalNumProperties * 100, "%)");
  }
}

//Need to create outputDirectory prior to opening files
if !exists(outputDirectory) {
   try {
      mkdir(outputDirectory);
   }
   catch {
      halt("*Unable to create directory ", outputDirectory);
   }
}
// Fill work queue with files to load up
var currLoc : int; 
var nFiles : int;
var fileNames : [0..-1] string;
for fileName in listdir(datasetDirectory, dirs=false) {
    if !fileName.endsWith(".csv") then continue;
    if nFiles == numMaxFiles then break;
    files.push_back(fileName);
    fileNames.push_back(datasetDirectory + fileName);
    currLoc += 1;
    nFiles += 1;
}

// Spread out the work across multiple locales.
var _currLoc : atomic int;
forall fileName in fileNames {
  td.started(1);
  wq.addWork(fileName, _currLoc.fetchAdd(1) % numLocales);
}
wq.flush();


// Initialize property maps; aggregation is used as properties can be remote to current locale.
forall fileName in doWorkLoop(wq, td) {
  for line in getLines(fileName) {
    var attrs = line.split(",");
    var qname = attrs[1].strip();
    var rdata = attrs[2].strip();

    vPropMap.create(rdata, aggregated=true);
    ePropMap.create(qname, aggregated=true);
  }
  td.finished();  
}
vPropMap.flushGlobal();
ePropMap.flushGlobal();
// t.stop();
writeln("Constructed Property Map with ", vPropMap.numPropertiesGlobal(), 
    " vertex properties and ", ePropMap.numPropertiesGlobal(), 
    " edge properties in ", t.elapsed(), "s");
t.clear();

writeln("Vertex Property Map");
printPropertyDistribution(vPropMap);
writeln("Edge Property Map");
printPropertyDistribution(ePropMap);

writeln("Constructing HyperGraph...");
t.start();
var hypergraph = new AdjListHyperGraph(vPropMap, ePropMap, new unmanaged Cyclic(startIdx=0));
t.stop();
writeln("Constructed HyperGraph in ", t.elapsed(), "s");
t.clear();
writeln("Populating HyperGraph...");

t.start();
// Spread out the work across multiple locales.
_currLoc.write(0);
forall fileName in fileNames {
  td.started(1);
  wq.addWork(fileName, _currLoc.fetchAdd(1) % numLocales);
}
wq.flush();

// Aggregate fetches to properties into another work queue; when we flush
// each of the property maps, their individual PropertyHandle will be finished.
// Also send the 'String' so that it can be reclaimed.
var handleWQ = new WorkQueue((unmanaged PropertyHandle?, unmanaged PropertyHandle?), 64 * 1024);
var handleTD = new TerminationDetector();
forall fileName in doWorkLoop(wq, td) {
  for line in getLines(fileName) {
    var attrs = line.split(",");
    var qname = attrs[1].strip();
    var rdata = attrs[2].strip();
    handleTD.started(1);
    handleWQ.addWork((vPropMap.getPropertyAsync(rdata), ePropMap.getPropertyAsync(qname)));
  }
  td.finished();
}
vPropMap.flushGlobal();
ePropMap.flushGlobal();

// Finally aggregate inclusions for the hypergraph.
hypergraph.startAggregation();
forall (vHandle, eHandle) in doWorkLoop(handleWQ, handleTD) {
  hypergraph.addInclusion(vHandle.get(), eHandle.get());
  delete vHandle;
  delete eHandle;
  handleTD.finished(1);
}
hypergraph.stopAggregation();
hypergraph.flushBuffers();

t.stop();
writeln("Populated HyperGraph in ", t.elapsed(), "s");
t.clear();
writeln("Number of Inclusions: ", hypergraph.getInclusions());
writeln("Deleting Duplicate edges: ", hypergraph.removeDuplicates());
writeln("Number of Inclusions: ", hypergraph.getInclusions());


t.start();