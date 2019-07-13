use CHGL;
use Time;
use Regexp;
use ReplicatedDist;
use FileSystem;
use ReplicatedVar;

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
var blacklistIPRegexp : [rcDomain] regexp;
var blacklistDNSNamesRegexp : [rcDomain] regexp; 
coforall loc in Locales do on loc {
  rcLocal(blacklistIPRegexp) = compile(blacklistDNSNamesRegex);
  rcLocal(blacklistDNSNamesRegexp) = compile(blacklistIPRegex);
}
var vPropMap = new PropertyMap(string);
var ePropMap = new PropertyMap(string);
var wq = new WorkQueue(int, WorkQueueUnlimitedAggregation);
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
  forall v in graph.getVertices() {
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
        for neighbor in graph.walk(v, s) {
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
        for vv in vertexBFS(graph, v, s) {
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
  forall e in graph.getEdges() {
    var dnsName = graph.getProperty(e);
    var isBadDNS = dnsName.matches(rcLocal(blacklistDNSNamesRegexp));
    if blacklistDNSNames.contains(dnsName) || isBadDNS.size != 0 {
      var f = open(outputDirectory + prefix + "/" + dnsName, iomode.cw).writer();
      writeln("(" + prefix + ") Found blacklisted DNS Name ", dnsName);

      // Print out its local neighbors...
      f.writeln("(" + prefix + ") Blacklisted DNS Name: ", dnsName);
      for s in 1..3 {
        f.writeln("\tLocal Neighborhood (s=", s, "):");
        for neighbor in graph.walk(e, s) {
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
        for ee in edgeBFS(graph, e, s) {
          var eee = graph.toEdge(ee);
          var str = "\t\t" + graph.getProperty(eee) + "\t";
          for n in graph.incidence(eee) {
            str += graph.getProperty(n) + ",";
          }
          f.writeln(str[..str.size - 1]);
          f.flush();
        }
      }
    }
  }
  writeln("Finished searching for blacklisted DNSs...");
}

writeln("Constructing PropertyMap...");
t.start();
// Fill work queue with files to load up
var currLoc : int; 
var nFiles : int;
var fileNames : [0..-1] string;
for fileName in listdir(datasetDirectory, dirs=false) {
    if !fileName.endsWith(".csv") then continue;
    if nFiles == numMaxFiles then break;
    files.push_back(fileName);
    fileNames.push_back(datasetDirectory + fileName);
    wq.addWork(nFiles, currLoc % numLocales);
    currLoc += 1;
    nFiles += 1;
}
wq.flush();
td.started(nFiles);

// Initialize property maps; aggregation is used as properties can be remote to current locale.
forall fileIdx in doWorkLoop(wq,td) { 
  for line in getLines(fileNames[fileIdx]) {
    var attrs = line.split(",");
    var qname = attrs[1];
    var rdata = attrs[2];

    vPropMap.create(rdata.strip(), aggregated=true);
    ePropMap.create(qname.strip(), aggregated=true);
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
writeln("Constructing HyperGraph...");
t.start();
var graph = new AdjListHyperGraph(vPropMap, ePropMap, new unmanaged Cyclic(startIdx=0));
t.stop();
writeln("Constructed HyperGraph in ", t.elapsed(), "s");
t.clear();
writeln("Populating HyperGraph...");
// Fill work queue with files to load up
currLoc = 0;
nFiles = 0;
for fileName in files {    
    wq.addWork(nFiles, currLoc % numLocales);
    currLoc += 1;
    nFiles += 1;
}
wq.flush();
td.started(nFiles);

t.start();
graph.startAggregation();
forall fileIdx in doWorkLoop(wq,td) { 
  for line in getLines(fileNames[fileIdx]) {
    var attrs = line.split(",");
    var qname = attrs[1];
    var rdata = attrs[2];
    
    graph.addInclusion(vPropMap.getProperty(rdata.strip()), ePropMap.getProperty(qname.strip()));
  }
  td.finished();  
}
graph.stopAggregation();
graph.flushBuffers();

t.stop();
writeln("Populated HyperGraph in ", t.elapsed(), "s");
t.clear();
writeln("Number of Inclusions: ", graph.getInclusions());
writeln("Deleting Duplicate edges: ", graph.removeDuplicates());
writeln("Number of Inclusions: ", graph.getInclusions());

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
