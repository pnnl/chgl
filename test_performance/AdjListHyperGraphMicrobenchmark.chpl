use CHGL;
use Time;

config const dataset = "DNS/tinyDNS.txt";

// We avoid using the PropertyMap here for two reasons...
// 1. We want to only measure the performance of the hypergraph
// 2. We want to measure generation of the hypergraph, which gets
//    performed during creation if we supply a property map.
// Hence we explicitly fill up an associative domain and create
// our own arbitrary mappings.

var timer = new Timer();
var vKeys : domain(string); // Vertex QName
var vValues : [vKeys] (int, int); // Vertex Locale and Index
var eKeys : domain(string); // Edge RData
var eValues : [eKeys] (int, int); // Edge Locale and Index

var vIdx : int;
var eIdx : int;
var locIdx : int;
var localeWork : [LocaleSpace] domain(2*int);

// Fill up keys and values from file.
for line in getLines(dataset) {
  var attrs = line.split(",");
  var qname = attrs[1]; 
  var rdata = attrs[2];
  
  // If the qname and rdata are unique, then we
  // update vIdx and eIdx respectively and round-robin
  // the allocation to each locale.
  var (vLocIdx, _vIdx) : 2 * int;
  var (eLocIdx, _eIdx) : 2 * int;
  if vKeys.contains(qname) {
    (vLocIdx, _vIdx) = vValues[qname];
  } else {
    vKeys += qname;
    (vLocIdx, _vIdx) = (locIdx % numLocales, vIdx);
    locIdx += 1;
    vIdx += 1;
  }
  if eKeys.contains(rdata) {
    (eLocIdx, _eIdx) = eValues[rdata];
  } else {
    eKeys += rdata;
    (eLocIdx, _eIdx) = (locIdx % numLocales, eIdx);
    locIdx += 1;
    eIdx += 1;
  }  
  localeWork[vLocIdx] += (_vIdx, _eIdx);
}

// After filling up the graph with work, we can now benchmark
timer.start();
var graph = new AdjListHyperGraph(vIdx, eIdx, new unmanaged Cyclic(startIdx=0));
timer.stop();
writeln("Graph Creation: ", timer.elapsed());
timer.clear();

timer.start();
coforall loc in Locales do on loc {
  const ourDom = localeWork[here.id];
  forall (vIdx, eIdx) in ourDom {
    graph.addInclusion(vIdx, eIdx);
  }
}
timer.stop();
writeln("AddInclusion: ", timer.elapsed());
timer.clear();

timer.start();
graph.destroy();
timer.stop();
writeln("Graph Destroy: ", timer.elapsed());
timer.clear();

graph = new AdjListHyperGraph(vIdx, eIdx, new unmanaged Cyclic(startIdx=0));
timer.start();
coforall loc in Locales do on loc {
  const ourDom = localeWork[here.id];
  forall (vIdx, eIdx) in ourDom {
    graph.addInclusionBuffered(vIdx, eIdx);
  }
}
graph.flushBuffers();
timer.stop();
writeln("AddInclusionBuffered: ", timer.elapsed());
timer.clear();

timer.start();
graph.getInclusions();
timer.stop();
writeln("GetInclusions: ", timer.elapsed());
timer.clear();

timer.start();
// Ensures compiler does not optimize this stuff away
var totalNeighborID : int;
forall e in graph.getEdges() with (+ reduce totalNeighborID) {
  for ee in graph.walk(e, isImmutable=false) do totalNeighborID += ee.id;
}
timer.stop();
writeln("Walk (s=1, serial, isImmutable=false): ", timer.elapsed());
timer.clear();

timer.start();
totalNeighborID = 0;
forall e in graph.getEdges() with (+ reduce totalNeighborID) {
  for ee in graph.walk(e, isImmutable=true) do totalNeighborID += ee.id;
}
timer.stop();
writeln("Walk (s=1, serial, isImmutable=true): ", timer.elapsed());
timer.clear();

timer.start();
totalNeighborID = 0;
forall e in graph.getEdges() with (+ reduce totalNeighborID) {
  forall ee in graph.walk(e, isImmutable=false) with (+ reduce totalNeighborID) do totalNeighborID += ee.id;
}
timer.stop();
writeln("Walk (s=1, parallel, isImmutable=false): ", timer.elapsed());
timer.clear();

timer.start();
totalNeighborID = 0;
forall e in graph.getEdges() with (+ reduce totalNeighborID) {
  forall ee in graph.walk(e, isImmutable=true) with (+ reduce totalNeighborID) do totalNeighborID += ee.id;
}
timer.stop();
writeln("Walk (s=1, parallel, isImmutable=true): ", timer.elapsed());
timer.clear();

var totalTime : real;
forall e in graph.getEdges() with (max reduce totalTime) {
  
  forall ee in graph.walk(e, isImmutable=true) with (max reduce totalTime) {
    var _timer = new Timer();
    _timer.start();
    graph.intersectionSize(e, ee, isImmutable=false);
    _timer.stop();
    totalTime = max(totalTime, _timer.elapsed());
  }
  
}
writeln("Intersection Size(isImmutable=false): ", totalTime);
timer.clear();

totalTime = 0;
forall e in graph.getEdges() with (max reduce totalTime) {
  forall ee in graph.walk(e, isImmutable=true) with (max reduce totalTime) {
    var _timer = new Timer();
    _timer.start();
    graph.intersectionSize(e, ee, isImmutable=true);
    _timer.stop();
    totalTime = max(totalTime, _timer.elapsed());
  }
}
writeln("Intersection Size (isImmutable=true): ", totalTime);
timer.clear();

timer.start();
forall e in graph.getEdges() {
  for v in graph.incidence(e, isImmutable=false) do ;
}
timer.stop();
writeln("Incidence (isImmutable=false): ", timer.elapsed());
timer.clear();

timer.start();
forall e in graph.getEdges() {
  for v in graph.incidence(e, isImmutable=true) do ;
}
timer.stop();
writeln("Incidence (isImmutable=true): ", timer.elapsed());
timer.clear();

timer.start();
graph.removeDuplicates();
timer.stop();
writeln("removeDuplicates: ", timer.elapsed());
timer.clear();

graph.destroy();