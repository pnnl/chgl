use CHGL;
use Time;
use Regexp;
use ReplicatedDist;
use FileSystem;
use ReplicatedVar;

/*
  Directory containing the DNS dataset in CSV format. Each file is parsed
  individually, in parallel, and distributed. This is liable to change to be
  more flexible, I.E to consider binary format (preprocessed), but for now
  it must be a directory containing files ending in ".csv".
*/
config const dataset = "../data/DNS/";
config const printTiming = true;

var t = new Timer();
var tt = new Timer();
var vPropMap = new PropertyMap(string);
var ePropMap = new PropertyMap(string);
tt.start();

proc getMetrics(graph) {
  var ttt = new Timer();
  ttt.start();
  {
    var vDeg = vertexDegreeDistribution(graph);
  }
  ttt.stop();
  if printTiming then writeln("Vertex Degree Distribution: ", ttt.elapsed());
  ttt.clear();
  ttt.start();
  {
    var eDeg = edgeDegreeDistribution(graph);
  }
  ttt.stop();
  if printTiming then writeln("Edge Cardinality Distribution: ", ttt.elapsed());
  // Compute component size distribution
  for s in 1..3 {
    ttt.start();
    var vComponentSizeDistribution = vertexComponentSizeDistribution(graph, s);
    writeln(for (i,j) in zip(vComponentSizeDistribution.domain, vComponentSizeDistribution) do (i,j):string);
    ttt.stop();
    if printTiming then writeln("Vertex Component Size Distribution (s=", s, "): ", ttt.elapsed());
    ttt.clear();
    ttt.start();
    var eComponentSizeDistribution = edgeComponentSizeDistribution(graph, s);
    writeln(for (i,j) in zip(eComponentSizeDistribution.domain, eComponentSizeDistribution) do (i,j):string);
    ttt.stop();
    if printTiming then writeln("Edge Component Size Distribution (s=", s, "): ", ttt.elapsed());
    ttt.clear();
  }
}

t.start();
// Initialize property maps; aggregation is used as properties can be remote to current locale.
for line in getLines(dataset) {
  var attrs = line.split(",");
  var qname = attrs[1];
  var rdata = attrs[2];

  vPropMap.create(rdata.strip(), aggregated=true);
  ePropMap.create(qname.strip(), aggregated=true);
}
vPropMap.flushGlobal();
ePropMap.flushGlobal();
t.stop();
if printTiming then writeln("Constructed Property Map: ", t.elapsed()); 
t.clear();

t.start();
var graph = new AdjListHyperGraph(vPropMap, ePropMap, new Cyclic(startIdx=0));
t.stop();
if printTiming then writeln("Constructed HyperGraph: ", t.elapsed());
t.clear();

t.start();
graph.startAggregation();
for line in getLines(dataset) {
  var attrs = line.split(",");
  var qname = attrs[1];
  var rdata = attrs[2];

  graph.addInclusion(vPropMap.getProperty(rdata.strip()), ePropMap.getProperty(qname.strip()));
}
graph.stopAggregation();
graph.flushBuffers();

t.stop();
if printTiming then writeln("Populated HyperGraph: ", t.elapsed());
t.clear();
t.start();
graph.removeDuplicates();
t.stop();
if printTiming then writeln("Removed duplicates: ", t.elapsed());
t.clear();

t.start();
getMetrics(graph);
t.stop();
if printTiming then writeln("Collected Metrics: ", t.elapsed());
t.clear();

t.start();
var vDupeHistogram = graph.collapseVertices();
t.stop();
if printTiming then writeln("Collapsed Vertices in HyperGraph: ", t.elapsed());
t.clear();
t.start();
var eDupeHistogram = graph.collapseEdges();
t.stop();
if printTiming then writeln("Collapsed Edges in HyperGraph: ", t.elapsed());
t.clear();
graph.destroy();
ePropMap.destroy();
vPropMap.destroy();
