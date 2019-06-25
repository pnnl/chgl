use CHGL;
use Time;
use Regexp;
use ReplicatedDist;
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

// Ensures that this never gets reclaimed automatically
// Gets around subtle bug where the string gets deallocated
class StringWrapper {
  const str : string;
  
  proc init(str : string) {
    this.str = new string(str, true);
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
var blacklistIPRegexp = compile(blacklistIPRegex);
var blacklistDNSNamesRegexp = compile(blacklistDNSNamesRegex);
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

proc getMetrics(graph, prefix, doComponents, cachedComponents) {
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
    if doComponents then for s in 1..3 {
        var componentMappings = cachedComponents[s].cachedComponentMappings;
        var componentsDom : domain(int);
        var components : [componentsDom] unmanaged Vector(graph._value.eDescType);
        for (ix, id) in zip(componentMappings.domain, componentMappings) {
            componentsDom += id;
            if components[id] == nil {
                components[id] = new unmanaged VectorImpl(graph._value.eDescType, {0..-1});
            }
            components[id].append(graph.toEdge(ix));
        }

        var eMax = max reduce [component in components] component.size();
        var vMax = max reduce [component in components] (+ reduce for edge in component do graph.degree(edge));         
        var vComponentSizes : [1..vMax] int;
        var eComponentSizes : [1..eMax] int;
        forall component in components with (+ reduce vComponentSizes, + reduce eComponentSizes) {
            eComponentSizes[component.size()] += 1;
            var numVertices : int;
            for e in component {
                numVertices += graph.degree(e);
            }
            vComponentSizes[numVertices] += 1;
        }

        f.writeln("(", prefix, ") Vertex Connected Component Size Distribution (s = " + s + "):");
        for (sz, freq) in zip(vComponentSizes.domain, vComponentSizes) {
            if freq != 0 then f.writeln("\t" + sz + "," + freq);
        }
        f.flush();

        f.writeln("(", prefix, ") Edge Connected Component Size Distribution (s = " + s + "):");
        for (sz, freq) in zip(eComponentSizes.domain, eComponentSizes) {
            if freq != 0 then f.writeln("\t" + sz + "," + freq);
        }
        f.flush();
        delete components;
    }
}

proc searchBlacklist(graph, prefix, cachedComponents) {
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
                var compId = cachedComponents[s].cachedComponentMappings[v.id];
                f.writeln("\tComponent (s=", s, "):");
                for (ix, id) in zip(graph.verticesDomain, cachedComponents[s].cachedComponentMappings) {
                    if id == compId {
                        var vv = graph.toVertex(ix);
                        var str = "\t\t" + graph.getProperty(vv) + "\t";
                        for n in graph.incidence(vv) {
                            str += graph.getProperty(n) + ",";
                        }
                        f.writeln(str[..str.size - 1]);
                        f.flush();
                    }
                }
            } 
        } 
    } writeln("Finished searching for blacklisted IPs...");
    forall e in graph.getEdges() {
        var dnsName = graph.getProperty(e);
        var isBadDNS = dnsName.matches(blacklistDNSNamesRegexp);
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
                var compId = cachedComponents[s].cachedComponentMappings[e.id];
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

writeln("Constructing HyperGraph...");
var graph = new AdjListHyperGraph(vPropMap, ePropMap);

writeln("Adding inclusions to HyperGraph...");
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
writeln("Hypergraph Construction: ", t.elapsed(), " seconds...");
f.writeln("Hypergraph Construction: ", t.elapsed());
t.clear();
writeln("Number of Inclusions: ", graph.getInclusions());
writeln("Deleting Duplicate edges: ", graph.removeDuplicates());
writeln("Number of Inclusions: ", graph.getInclusions());

// Cached components to avoid its costly recalculation...
pragma "default intent is ref"
record CachedComponents {
    var cachedComponentMappingsDomain = graph.edgesDomain;
    var cachedComponentMappings : [cachedComponentMappingsDomain] int;    
}
var cachedComponents : [1..3] CachedComponents;
var cachedComponentMappingsInitialized = false;
if preCollapseBlacklist {
    t.start();
    if !cachedComponentMappingsInitialized {
        for s in 1..3 do cachedComponents[s].cachedComponentMappings = getEdgeComponentMappings(graph, s);
        cachedComponentMappingsInitialized = true;
        writeln("(Pre-Collapse) Generated Cache of Connected Components for 1..3 in ", t.elapsed(), " seconds...");
        t.clear();
    }
    searchBlacklist(graph, "Pre-Collapse", cachedComponents);
    t.stop();
    writeln("(Pre-Collapse) Blacklist Scan: ", t.elapsed(), " seconds...");
    f.writeln("Computed Pre-Collapse Blacklist: ", t.elapsed());
    t.clear();
}
if preCollapseMetrics {
    t.start();
    if preCollapseComponents && !cachedComponentMappingsInitialized {
        for s in 1..3 do cachedComponents[s].cachedComponentMappings = getEdgeComponentMappings(graph, s);
        cachedComponentMappingsInitialized = true;
        writeln("(Pre-Collapse) Generated Cache of Connected Components for 1..3 in ", t.elapsed(), " seconds...");
        f.writeln("Generated Pre-Collapse Components: ", t.elapsed());
        t.clear();
    }
    getMetrics(graph, "Pre-Collapse", preCollapseComponents, cachedComponents);
    t.stop();
    writeln("(Pre-Collapse) Collected Metrics: ", t.elapsed());
    f.writeln("Collected Pre-Collapse Metrics: ", t.elapsed());
    t.clear();
}

cachedComponentMappingsInitialized = false;

writeln("Collapsing HyperGraph...");
t.start();
var (vDupeHistogram, eDupeHistogram) = graph.collapse();
t.stop();
writeln("Collapsed Hypergraph: ", t.elapsed(), " seconds...");
f.writeln("Collapsed Hypergraph: ", t.elapsed());
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
    if !cachedComponentMappingsInitialized {
        for s in 1..3 do cachedComponents[s].cachedComponentMappings = getEdgeComponentMappings(graph, s);
        cachedComponentMappingsInitialized = true;
        writeln("(Post-Collapse) Generated Cache of Connected Components for 1..3 in ", t.elapsed(), " seconds...");
        f.writeln("Generated Post-Collapse Components: ", t.elapsed());
        t.clear();
    }
    searchBlacklist(graph, "Post-Collapse", cachedComponents);
    t.stop();
    writeln("(Post-Collapse) Blacklist Scan: ", t.elapsed(), " seconds...");
    f.writeln("Computed Post-Collapse Blacklist: ", t.elapsed());
    t.clear();
}
if postCollapseMetrics {
    t.start();
    if postCollapseComponents && !cachedComponentMappingsInitialized {
        for s in 1..3 do cachedComponents[s].cachedComponentMappings = getEdgeComponentMappings(graph, s);
        cachedComponentMappingsInitialized = true;
        writeln("(Post-Collapse) Generated Cache of Connected Components for 1..3 in ", t.elapsed(), " seconds...");
        f.writeln("Generated Components: ", t.elapsed());
        t.clear();
    }
    getMetrics(graph, "Post-Collapse", postCollapseComponents, cachedComponents);
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
f.writeln("Removed Isolated Components: ", t.elapsed());
f.writeln("Isolated Components Removed: ", numIsolatedComponents);
t.clear();

writeln("Number of Inclusions: ", graph.getInclusions());

cachedComponentMappingsInitialized = false;

if postRemovalBlacklist {
    t.start();
    if !cachedComponentMappingsInitialized {
        for s in 1..3 do cachedComponents[s].cachedComponentMappings = getEdgeComponentMappings(graph, s);
        cachedComponentMappingsInitialized = true;
        writeln("(Post-Removal) Generated Cache of Connected Components for 1..3 in ", t.elapsed(), " seconds...");
        f.writeln("Generated Post-Removal Components: ", t.elapsed());
        t.clear();
    }
    searchBlacklist(graph, "Post-Removal", cachedComponents);
    t.stop();
    writeln("(Post-Removal) Blacklist Scan: ", t.elapsed(), " seconds...");
    f.writeln("Computed Post-Removal Blacklist: ", t.elapsed());
    t.clear();
}
if postRemovalMetrics {
    t.start();
    if postRemovalComponents && !cachedComponentMappingsInitialized {
        for s in 1..3 do cachedComponents[s].cachedComponentMappings = getEdgeComponentMappings(graph, s);
        cachedComponentMappingsInitialized = true;
        writeln("(Post-Removal) Generated Cache of Connected Components for 1..3 in ", t.elapsed(), " seconds...");
        f.writeln("Generated Post-Removal Components: ", t.elapsed());
        t.clear();
    }
    getMetrics(graph, "Post-Removal", postRemovalComponents, cachedComponents);
    t.stop();
    writeln("(Post-Removal) Collected Metrics: ", t.elapsed(), " seconds...");
    f.writeln("Collected Post-Removal Metrics: ", t.elapsed());
    t.clear();
}

cachedComponentMappingsInitialized = false;

writeln("Removing non-toplexes...");
t.start();
var toplexStats = graph.collapseSubsets();
t.stop();
writeln("Removed non-toplexes: ", t.elapsed());
f.writeln("Removed non-toplexes:", t.elapsed());
f.writeln("Distribution of Non-Toplex Edges:");
for (deg, freq) in zip(toplexStats.domain, toplexStats) {
    if freq != 0 then f.writeln("\t", deg, ",", freq);
}
t.clear();

cachedComponentMappingsInitialized = false;
if postToplexBlacklist {
    t.start();
    if !cachedComponentMappingsInitialized {
        for s in 1..3 do cachedComponents[s].cachedComponentMappings = getEdgeComponentMappings(graph, s);
        cachedComponentMappingsInitialized = true;
        writeln("(Post-Collapse) Generated Cache of Connected Components for 1..3 in ", t.elapsed(), " seconds...");
        f.writeln("Generated Post-Collapse Components: ", t.elapsed());
        t.clear();
    }
    searchBlacklist(graph, "Post-Toplex", cachedComponents);
    t.stop();
    writeln("(Post-Collapse) Blacklist Scan: ", t.elapsed(), " seconds...");
    f.writeln("Computed Blacklist: ", t.elapsed());
    t.clear();
}

if postToplexMetrics {
    t.start();
    if !cachedComponentMappingsInitialized {
        for s in 1..3 do cachedComponents[s].cachedComponentMappings = getEdgeComponentMappings(graph, s);
        cachedComponentMappingsInitialized = true;
        writeln("(Post-Toplex) Generated Cache of Connected Components for 1..3 in ", t.elapsed(), " seconds...");
        f.writeln("Generated Post-Toplex Components: ", t.elapsed());
        t.clear();
    }
    getMetrics(graph, "Post-Toplex", postToplexComponents, cachedComponents);
    t.stop();
    writeln("(Post-Toplex) Collected Metrics: ", t.elapsed(), " seconds...");
    f.writeln("Collected Post-Toplex Metrics: ", t.elapsed());
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

cachedComponentMappingsInitialized = false;
if !cachedComponentMappingsInitialized {
    for s in 1..3 do cachedComponents[s].cachedComponentMappings = getEdgeComponentMappings(graph, s);
    cachedComponentMappingsInitialized = true;
    writeln("(Post-Toplex) Generated Cache of Connected Components for 1..3 in ", t.elapsed(), " seconds...");
    f.writeln("Generated Components: ", t.elapsed());
    t.clear();
}

writeln("Printing out components of collapsed toplex graph...");
for s in 1..3 {
  const sdir = componentsDirectory + "s=" + s + "/";
  if !exists(sdir) {
    try {
      mkdir(sdir);
    }
    catch {
      halt("*Unable to create directory ", sdir);
    }
  }

  writeln("Edge Connected Components (s = ", s, "): ");
  forall (ix, id) in zip(graph.edgesDomain, cachedComponents[s].cachedComponentMappings) {
    var ee = graph.toEdge(ix);
    var fff = open(componentsDirectory + "s=" + s + "/" + graph.getProperty(ee), iomode.cw).writer();
    var str = "";
    for n in graph.incidence(ee) {
      str += graph.getProperty(n) + ",";
    }
    str = str[..str.size - 1];
    fff.writeln(str);
    fff.close();
  }
}

writeln("Finished in ", tt.elapsed(), " seconds...");
f.writeln("Finished in ", tt.elapsed(), " seconds...");
f.close();
ff.close();
if doProfiling then endProfile();
