use CHGL;
use Time;
use Regexp;
use FileSystem;

/*
  The Regular Expression used for searching for IP Addresses.
*/
config const blacklistIPRegex = "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$";
/*
  Directory containing the DNS dataset in CSV format. Each file is parsed
  individually, in parallel, and distributed. This is liable to change to be
  more flexible, I.E to consider binary format (preprocessed), but for now
  it must be a directory containing files ending in ".csv".
*/
config const datasetDirectory = "../data/DNS/";
/*
  Data file containing a list of blacklisted ip addresses. Checked for after all segmentation
  is performed.
*/
config const blacklistIPs = "../data/ip-most-wanted.txt";
/*
  Data file containing a list of blacklisted dns names. Checked for after all segmentation
  is performed.
*/
config const blacklistDNS = "../data/dns-most-wanted.txt";
/*
  Output directory.
*/
config const outputDirectory = "tmp/";
/*
  Name of output file containing metrics.
*/
config const metricsOutput = outputDirectory + "metrics.txt";
/*
  Name of output directory for components
*/
config const componentsDirectory = outputDirectory + "components/";
/*
  Name of output file containing hypergraph list of hyperedges.
*/
config const hypergraphOutput = outputDirectory + "hypergraph.txt";
/*
  Regular expression for blacklist of DNS names.
*/
config const blacklistDNSNamesRegex = "^[a-zA-Z]{4,5}\\.(pw|us|club|info|site|top)$";
// Obtain metrics prior to collapsing subsets
config const preCollapseMetrics = true;
// Obtain components prior to collapsing subsets
config const preCollapseComponents = true;
// Scan for blacklist prior to collapsing subsets 
config const preCollapseBlacklist = true;
// Obtain metrics prior to collapsing subsets
config const postCollapseMetrics = true;
// Obtain components after collapsing subsets
config const postCollapseComponents = true;
// Scan for blacklist after collapsing subsets 
config const postCollapseBlacklist = true;
// Obtain metrics after removing isolated components
config const postRemovalMetrics = true;
// Obtain components after removing isolated components
config const postRemovalComponents = true;
// Scan for blacklist after removing isolated components
config const postRemovalBlacklist = true;
// Perform toplex reduction.
config const doToplexReduction = false;
// Obtain metrics after reducing to toplex hyperedges.
config const postToplexMetrics = true;
// Obtain components after reducing to toplex hyperedges.
config const postToplexComponents = true;
// Scan for blacklist after reducing to toplex hyperedges. 
config const postToplexBlacklist = true;
// Maximum number of files to process.
config const numMaxFiles = max(int(64));
// Perform profiling (specific flags listed in src/Utilities.chpl)
config const doProfiling = false;
// The index for the DNS name
config const dnsNameIndex = 1;
// The index for the IP Address
config const ipAddressIndex = 2;
// Skips first line of header file.
config const skipHeader = false;
// Print out used memory after constructing property map and after
// constructing hypergraph, then quit.
config const memTestOnly = false;

//Need to create outputDirectory prior to opening files
if !exists(outputDirectory) {
   try {
      mkdir(outputDirectory);
   }
   catch {
      halt("*Unable to create directory ", outputDirectory);
   }
}

if !exists(componentsDirectory) {
   try {
      mkdir(componentsDirectory);
   }
   catch {
      halt("*Unable to create directory ", componentsDirectory);
   }
}

if doProfiling then beginProfile("Blacklist-Profile");

var t = new Timer();
var tt = new Timer();
var files : [0..-1] string;
var f = open(metricsOutput, iomode.cw).writer();
var blacklistIPRegexp = new Privatized(regexp);
var blacklistDNSNamesRegexp = new Privatized(regexp); 
forall (ipRegexp, dnsRegexp) in zip(blacklistIPRegexp.broadcast, blacklistDNSNamesRegexp.broadcast) {
  ipRegexp = compile(blacklistDNSNamesRegex);
  dnsRegexp = compile(blacklistIPRegex);
}
var vPropMap = new PropertyMap(string);
var ePropMap = new PropertyMap(string);
var wq = new WorkQueue(string, 1024);
var td = new TerminationDetector();
var blacklistIPAddresses : domain(string);
var blacklistDNSNames : domain(string);
tt.start();

for line in getLines(blacklistIPs) {
    blacklistIPAddresses += line;
}
for line in getLines(blacklistDNS) {
    blacklistDNSNames += line;
}

proc printPropertyDistribution(propMap) : void {
  var localNumProperties : [LocaleSpace] int;
  coforall loc in Locales do on loc do localNumProperties[here.id] = propMap.numProperties();
  var globalNumProperties = + reduce localNumProperties;
  for locid in LocaleSpace {
    writeln("Locale#", locid, " has ", localNumProperties[locid], "(", localNumProperties[locid] : real / globalNumProperties * 100, "%)");
  }
}

proc getMetrics(graph, prefix, doComponents) {
    f.writeln("(", prefix, ") #V = ", graph.numVertices);
    f.writeln("(", prefix, ") #E = ", graph.numEdges);
    f.flush();
    f.writeln("(", prefix, ") Vertex Degree Distribution:");
    {
        var vDeg = vertexDegreeDistribution(graph);
        for (deg, freq) in zip(vDeg.domain, vDeg) {
            if freq != 0 then f.writeln("\t", deg, ",", freq);
        }
    }
    f.flush();
    f.writeln("(", prefix, ") Edge Cardinality Distribution:");
    {
        var eDeg = edgeDegreeDistribution(graph);
        for (deg, freq) in zip(eDeg.domain, eDeg) {
            if freq != 0 then f.writeln("\t", deg, ",", freq);
        }
    }
    f.flush();
    // Compute component size distribution
    if doComponents then for s in 1..3 {
      var vComponentSizeDistribution = vertexComponentSizeDistribution(graph, s);
      f.writeln("(", prefix, ") Vertex Connected Component Size Distribution (s = " + s + "):");
      for (sz, freq) in zip(vComponentSizeDistribution.domain, vComponentSizeDistribution) {
        if freq != 0 then f.writeln("\t" + sz + "," + freq);
      }
      f.flush();

      var eComponentSizeDistribution = edgeComponentSizeDistribution(graph, s);
      f.writeln("(", prefix, ") Edge Connected Component Size Distribution (s = " + s + "):");
      for (sz, freq) in zip(eComponentSizeDistribution.domain, eComponentSizeDistribution) {
        if freq != 0 then f.writeln("\t" + sz + "," + freq);
      }
      f.flush();
    }
}

proc searchBlacklist(graph, prefix) {
  // Scan for most wanted...
  writeln("(" + prefix + ") Searching for known offenders...");
  //create directory
  if !exists(outputDirectory + prefix) {
    try{
      mkdir(outputDirectory + prefix);
    }
    catch{
      writeln("unable to create directory", outputDirectory + prefix);
    }
  }
  forall v in graph.getVertices() with (in blacklistIPAddresses) {
    var ip = graph.getProperty(v);
    if blacklistIPAddresses.contains(ip) {
      var f = open(outputDirectory +"/"+ prefix + "/" + ip,iomode.cw).writer();
      f.writeln("Blacklisted ip address ", ip);
      halt("Vertex blacklist scan not implemented...");
      // TODO! CORRECT THIS, THIS IS WRONG!
      // Print out its local neighbors...
      f.writeln("(" + prefix + ") Blacklisted IP Address: ", ip);
      for s in 1..3 {
        f.writeln("\tLocal Neighborhood (s=", s, "):");
        forall neighbor in graph.walk(v, s, isImmutable=true) {
          var str = "\t\t" + graph.getProperty(neighbor) + "\t";
          for n in graph.incidence(neighbor) {
            str += graph.getProperty(n) + ",";
          }
          f.writeln(str[..str.size - 1]);
          f.flush();
        }
        f.flush();
      }

      // Print out its component
      for s in 1..3 {
        f.writeln("\tComponent (s=", s, "):");
        forall vv in vertexBFS(graph, v, s) {
          var vvv = graph.toVertex(vv);
          var str = "\t\t" + graph.getProperty(vvv) + "\t";
          for n in graph.incidence(vvv) {
            str += graph.getProperty(n) + ",";
          }
          f.writeln(str[..str.size - 1]);
          f.flush();
        }
      } 
    } 
  } writeln("Finished searching for blacklisted IPs...");
  forall e in graph.getEdges() with (in blacklistDNSNames) {
    chpl_task_yield();
    var monsterEdge : bool;
    var dnsName = graph.getProperty(e);
    var isBadDNS = dnsName.matches(blacklistDNSNamesRegexp.get());
    if blacklistDNSNames.contains(dnsName) || isBadDNS.size != 0 {
      var f = open(outputDirectory + prefix + "/" + dnsName, iomode.cw).writer();
      writeln("(" + prefix + ") Found blacklisted DNS Name ", dnsName);

      // Print out its local neighbors...
      f.writeln("(" + prefix + ") Blacklisted DNS Name: ", dnsName);
      var timer = new Timer();
      var globalTimer = new Timer();
      globalTimer.start();
      for s in 1..3 {
        timer.start();
        f.writeln("\tLocal Neighborhood (s=", s, "):");
        var numInclusions : int;
        forall neighbor in graph.walk(e, s, isImmutable=true) with (+ reduce numInclusions) {
          var str = "\t\t" + graph.getProperty(neighbor) + "\t";
          for n in graph.incidence(neighbor) {
            str += graph.getProperty(n) + ",";
          }
          f.writeln(str[..str.size - 1]);
          f.flush();
          chpl_task_yield();
          numInclusions += graph.degree(neighbor);
        }
        if numInclusions > 100000 {
          writeln(dnsName, " is a monster edge for (s=", s, ") with ", numInclusions, " inclusions.");
          monsterEdge = true;
        }
        f.flush();
        timer.stop();
        writeln("Neighbors of ", dnsName, " (s=", s, "): ", timer.elapsed());
        timer.clear();
      }
      globalTimer.stop();
      writeln("Neighbors of ", dnsName, " in total: ", globalTimer.elapsed());
      globalTimer.clear();

      // Print out its component
      globalTimer.start();
      for s in 1..3 {
        chpl_task_yield();
        timer.start();
        f.writeln("\tComponent (s=", s, "):");
        forall ee in edgeBFS(graph, e, s, useMaximumParallelism=monsterEdge) {
          var eee = graph.toEdge(ee);
          var str = "\t\t" + graph.getProperty(eee) + "\t";
          for n in graph.incidence(eee) {
            str += graph.getProperty(n) + ",";
          }
          f.writeln(str[..str.size - 1]);
          chpl_task_yield();
          f.flush();
        }
        timer.stop();
        writeln("Component of ", dnsName, " (s=", s, "): ", timer.elapsed());
      }
      globalTimer.stop();
      writeln("Component of ", dnsName, " in total: ", globalTimer.elapsed());
    }
  }
  writeln("Finished searching for blacklisted DNSs...");
}

writeln("Constructing PropertyMap...");
t.start();
/*
  TODO: DO NOT DO THIS! This results in hitting OOM extremely quickly!
  Instead just go back to doling out files to evenly distributed locales
*/
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
t.stop();
writeln("Constructed Property Map with ", vPropMap.numPropertiesGlobal(), 
    " vertex properties and ", ePropMap.numPropertiesGlobal(), 
    " edge properties in ", t.elapsed(), "s");
t.clear();

writeln("Vertex Property Map");
printPropertyDistribution(vPropMap);
writeln("Edge Property Map");
printPropertyDistribution(ePropMap);

if memTestOnly {
  // (memUsed, physMem)
  var localeMemStats : [LocaleSpace] (int, int);
  coforall loc in Locales do on loc {
    localeMemStats[here.id] = (memoryUsed():int, here.physicalMemory(MemUnits.GB));
    printMemAllocs();
  }

  for (locIdx, (memUsed, physMem)) in zip(LocaleSpace, localeMemStats) {
    writeln(Locales[locIdx], ": ", ((memUsed / 1024):real / 1024) / 1024, "GB / ", physMem, "GB");
  }
}

writeln("Constructing HyperGraph...");
t.start();
var graph = new AdjListHyperGraph(vPropMap, ePropMap, new unmanaged Cyclic(startIdx=0));
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
graph.startAggregation();
forall (vHandle, eHandle) in doWorkLoop(handleWQ, handleTD) {
  graph.addInclusion(vHandle.get(), eHandle.get());
  delete vHandle;
  delete eHandle;
  handleTD.finished(1);
}
graph.stopAggregation();
graph.flushBuffers();

t.stop();
writeln("Populated HyperGraph in ", t.elapsed(), "s");
t.clear();
writeln("Number of Inclusions: ", graph.getInclusions());
writeln("Deleting Duplicate edges: ", graph.removeDuplicates());
writeln("Number of Inclusions: ", graph.getInclusions());

if memTestOnly {
  // (memUsed, physMem)
  var localeMemStats : [LocaleSpace] (int, int);
  coforall loc in Locales do on loc {
    localeMemStats[here.id] = (memoryUsed():int, here.physicalMemory(MemUnits.GB));
  }

  for (locIdx, (memUsed, physMem)) in zip(LocaleSpace, localeMemStats) {
    writeln(Locales[locIdx], ": ", ((memUsed / 1024):real / 1024) / 1024, "GB / ", physMem, "GB");
  }
  exit();
}

if preCollapseBlacklist {
    t.start();
    searchBlacklist(graph, "Pre-Collapse");
    t.stop();
    writeln("(Pre-Collapse) Blacklist Scan: ", t.elapsed(), " seconds...");
    f.writeln("Computed Pre-Collapse Blacklist: ", t.elapsed());
    t.clear();
}
if preCollapseMetrics {
    t.start();
    getMetrics(graph, "Pre-Collapse", preCollapseComponents);
    t.stop();
    writeln("(Pre-Collapse) Collected Metrics: ", t.elapsed());
    f.writeln("Collected Pre-Collapse Metrics: ", t.elapsed());
    t.clear();
}

writeln("Collapsing Vertices in HyperGraph...");
t.start();
var vDupeHistogram = graph.collapseVertices();
t.stop();
writeln("Collapsed Vertices in HyperGraph in ", t.elapsed(), "s");
t.clear();
writeln("Collapsing Edges in HyperGraph...");
t.start();
var eDupeHistogram = graph.collapseEdges();
t.stop();
writeln("Collapsed Edges in HyperGraph in ", t.elapsed(), "s");
t.clear();

writeln("Number of Inclusions: ", graph.getInclusions());

f.writeln("Distribution of Duplicate Vertex Counts:");
for (deg, freq) in zip(vDupeHistogram.domain, vDupeHistogram) {
    if freq != 0 then f.writeln("\t", deg, ",", freq);
}
f.writeln("Distribution of Duplicate Edge Counts:");
for (deg, freq) in zip(eDupeHistogram.domain, eDupeHistogram) {
    if freq != 0 then f.writeln("\t", deg, ",", freq);
}

if postCollapseBlacklist {
    t.start();
    searchBlacklist(graph, "Post-Collapse");
    t.stop();
    writeln("(Post-Collapse) Blacklist Scan: ", t.elapsed(), " seconds...");
    f.writeln("Computed Post-Collapse Blacklist: ", t.elapsed());
    t.clear();
}
if postCollapseMetrics {
    t.start();
    getMetrics(graph, "Post-Collapse", postCollapseComponents);
    t.stop();
    writeln("(Post-Collapse) Collected Metrics: ", t.elapsed(), " seconds...");
    f.writeln("Collected Post-Collapse Metrics: ", t.elapsed());
    t.clear();
}

writeln("Removing isolated components...");
t.start();
var numIsolatedComponents = graph.removeIsolatedComponents();
t.stop();
writeln("Removed isolated components: ", t.elapsed());
f.writeln("Isolated Components Removed: ", numIsolatedComponents);
t.clear();

writeln("Number of Inclusions: ", graph.getInclusions());

if postRemovalBlacklist {
    t.start();
    searchBlacklist(graph, "Post-Removal");
    t.stop();
    writeln("(Post-Removal) Blacklist Scan: ", t.elapsed(), " seconds...");
    t.clear();
}
if postRemovalMetrics {
    t.start();
    getMetrics(graph, "Post-Removal", postRemovalComponents);
    t.stop();
    writeln("(Post-Removal) Collected Metrics: ", t.elapsed(), " seconds...");
    t.clear();
}

if doToplexReduction {
  writeln("Removing non-toplexes...");
  t.start();
  var toplexStats = graph.collapseSubsets();
  t.stop();
  writeln("Removed non-toplexes: ", t.elapsed());
  f.writeln("Distribution of Non-Toplex Edges:");
  for (deg, freq) in zip(toplexStats.domain, toplexStats) {
      if freq != 0 then f.writeln("\t", deg, ",", freq);
  }
  t.clear();

  if postToplexBlacklist {
      t.start();
      searchBlacklist(graph, "Post-Toplex");
      t.stop();
      writeln("(Post-Collapse) Blacklist Scan: ", t.elapsed(), " seconds...");
      t.clear();
  }

  if postToplexMetrics {
      t.start();
      getMetrics(graph, "Post-Toplex", postToplexComponents);
      t.stop();
      writeln("(Post-Toplex) Collected Metrics: ", t.elapsed(), " seconds...");
      t.clear();
  }
}

writeln("Printing out collapsed toplex graph...");
var ff = open(hypergraphOutput, iomode.cw).writer();
forall e in graph.getEdges() {
    var str = graph.getProperty(e) + "\t";
    for v in graph.incidence(e) {
        str += graph.getProperty(v) + ",";
    }
    ff.writeln(str[1..#(str.size - 1)]);
}
writeln("Finished in ", tt.elapsed(), " seconds...");
f.close();
ff.close();
if doProfiling then endProfile();
