use Utilities;
use PropertyMap;
use AdjListHyperGraph;
use Time;
use Regexp;
use WorkQueue;
use Metrics;
use Components;
use Traversal;
use ReplicatedDist;
use FileSystem;

config const ValidIPRegex = "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$";
config const datasetDirectory = "../../data/DNS/";
config const badDNSNamesRegex = "^[a-zA-Z]{4,5}\\.(pw|us|club|info|site|top)\\.$";
config const preCollapseMetrics = true;
config const preCollapseComponents = true;
config const preCollapseBlacklist = true;
config const postCollapseMetrics = true;
config const postCollapseComponents = true;
config const postCollapseBlacklist = true;
config const postRemovalMetrics = true;
config const postRemovalComponents = true;
config const postRemovalBlacklist = true;
config const numMaxFiles = max(int(64));

var ValidIPRegexp = compile(ValidIPRegex);
var badDNSNamesRegexp = compile(badDNSNamesRegex);
var f = open("metrics.txt", iomode.cw).writer();
var t = new Timer();
var tt = new Timer();
tt.start();
var wq = new WorkQueue(string);

var badIPAddresses : domain(string);
var badDNSNames : domain(string);
for line in getLines("../../data/ip-most-wanted.txt") {
    badIPAddresses += line;
}
for line in getLines("../../data/dns-most-wanted.txt") {
    badDNSNames += line;
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
    if doComponents then for s in 1..3 {
        var components = getEdgeComponents(graph, s);
        var eMax = max reduce [component in components] component.size();
        var vMax = max reduce [component in components] (+ reduce for edge in component do graph.numNeighbors(edge));         
        var vComponentSizes : [1..vMax] int;
        var eComponentSizes : [1..eMax] int;
        forall component in components with (+ reduce vComponentSizes, + reduce eComponentSizes) {
            eComponentSizes[component.size()] += 1;
            var numVertices : int;
            for e in component {
                numVertices += graph.numNeighbors(e);
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

proc searchBlacklist(graph, prefix) {
    // Scan for most wanted...
    writeln("(" + prefix + ") Searching for known offenders...");
    var ioLock$ : sync bool;
    forall v in graph.getVertices() {
        var ip = graph.getProperty(v);
        if badIPAddresses.member(ip) {
            ioLock$ = true;
            writeln("(" + prefix + ") Found blacklisted ip address ", ip);
            
            // Print out its local neighbors...
            f.writeln("(" + prefix + ") Blacklisted IP Address: ", ip);
            for s in 1..3 {
                f.writeln("\tLocal Neighborhood (s=", s, "):");
                for neighbor in graph.walk(v, s) {
                    var str = "\t\t" + graph.getProperty(neighbor) + "\t";
                    for n in graph.getNeighbors(neighbor) {
                        str += graph.getProperty(n) + ",";
                    }
                    f.writeln(str[..str.size - 2]);
                    f.flush();
                }
                f.flush();
            }

            // Print out its component
            for s in 1..3 {
                f.writeln("\tComponent (s=", s, "):");
                for vv in vertexBFS(graph, v, s) {
                    var str = "\t\t" + graph.getProperty(vv) + "\t";
                    for n in graph.getNeighbors(vv) {
                        str += graph.getProperty(n) + ",";
                    }
                    f.writeln(str[..str.size - 2]);
                    f.flush();
                }
            }
          ioLock$;
        }
    }
    forall e in graph.getEdges() {
        var dnsName = graph.getProperty(e);
        var isBadDNS = dnsName.matches(badDNSNamesRegexp);
        if badDNSNames.member(dnsName) || isBadDNS.size != 0 {
            ioLock$ = true;
            writeln("(" + prefix + ") Found blacklisted DNS Name ", dnsName);
            
            // Print out its local neighbors...
            f.writeln("(" + prefix + ") Blacklisted DNS Name: ", dnsName);
            for s in 1..3 {
                f.writeln("\tLocal Neighborhood (s=", s, "):");
                for neighbor in graph.walk(e, s) {
                    var str = "\t\t" + graph.getProperty(neighbor) + "\t";
                    for n in graph.getNeighbors(neighbor) {
                        str += graph.getProperty(n) + ",";
                    }
                    f.writeln(str[..str.size - 2]);
                    f.flush();
                }
                f.flush();
            }

            // Print out its component
            for s in 1..3 {
                f.writeln("\tComponent (s=", s, "):");
                for ee in edgeBFS(graph, e, s) {
                    var str = "\t\t" + graph.getProperty(ee) + "\t";
                    for n in graph.getNeighbors(ee) {
                        str += graph.getProperty(n) + ",";
                    }
                    f.writeln(str[..str.size - 2]);
                    f.flush();
                }
            }
          ioLock$;
        }
    }
    writeln("Finished searching for blacklisted IPs...");
}

writeln("Constructing PropertyMap...");
t.start();
// Fill work queue with files to load up
var currLoc : int; 
var nFiles : int;
for fileName in listdir(datasetDirectory, dirs=false) {
    if !fileName.endsWith(".csv") then continue;
    if nFiles == numMaxFiles then break;
    wq.addWork(datasetDirectory + fileName, currLoc % numLocales);
    currLoc += 1;
    nFiles += 1;
}
wq.flush();

// Initialize property maps
var masterPropertyMap = EmptyPropertyMap;
{
    var propertyMapsDomain = {0..#here.maxTaskPar} dmapped Replicated();
    var propertyMaps : [propertyMapsDomain] PropertyMap(string, string);
    coforall loc in Locales do on loc {
        coforall tid in 0..#here.maxTaskPar {
            var propMap = new PropertyMap(string, string);
            while true {
                var (hasFile, fileName) = wq.getWork();
                if !hasFile {
                    break;
                }
                
                for line in getLines(fileName) {
                var attrs = line.split("\t");
                var qname = attrs[2];
                var rdata = attrs[4];

                // Empty IP or DNS
                if qname == "" || rdata == "" then continue;
                // IP Address as DNS Name
                var goodQName = qname.matches(ValidIPRegexp);
                if goodQName.size != 0 then continue;

                for ip in rdata.split(",") {
                    var goodIP = ip.matches(ValidIPRegexp);
                    if goodIP.size != 0 {
                    propMap.addVertexProperty(ip);
                    propMap.addEdgeProperty(qname);
                    }
                }
                }
            }
            propertyMaps[tid] = propMap;
        }
        // Do Merge...
        if propertyMaps.size > 1 {
            for propMap in propertyMaps[1..] {
                propertyMaps[0].append(propMap);
            }
        }
    }
    // Do Merge
    masterPropertyMap = propertyMaps[0];
    if numLocales > 1 {
        for loc in Locales do on loc {
            masterPropertyMap.append(propertyMaps[0]);
        }
    }
}

t.stop();
writeln("Reading Property Map: ", t.elapsed());
t.clear();

t.start();
writeln("Constructing HyperGraph...");
var graph = new AdjListHyperGraph(masterPropertyMap);

writeln("Adding inclusions to HyperGraph...");
// Fill work queue with files to load up
currLoc = 0;
nFiles = 0;
for fileName in listdir(datasetDirectory, dirs=false) {
    if !fileName.endsWith(".csv") {
      writeln("Skipping ", fileName);
      continue;
    }
    if nFiles == numMaxFiles then break;
    
    wq.addWork(datasetDirectory + fileName, currLoc % numLocales);
    currLoc += 1;
    nFiles += 1;
}
wq.flush();

coforall loc in Locales do on loc {
    coforall tid in 0..#here.maxTaskPar {
        while true {
            var (hasFile, fileName) = wq.getWork();
            if !hasFile {
                break;
            }
            
            for line in getLines(fileName) {
              var attrs = line.split("\t");
              var qname = attrs[2];
              var rdata = attrs[4];

              // Empty IP or DNS
              if qname == "" || rdata == "" then continue;
              // IP Address as DNS Name
              var goodQName = qname.matches(ValidIPRegexp);
              if goodQName.size != 0 then continue;

              for ip in rdata.split(",") {
                var goodIP = ip.matches(ValidIPRegexp);
                if goodIP.size != 0 {
                  graph.addInclusion(masterPropertyMap.getVertexProperty(ip), masterPropertyMap.getEdgeProperty(qname));
                }
              }
            }
        }
    }
}

t.stop();
writeln("Hypergraph Construction: ", t.elapsed());
t.clear();
writeln("Number of Inclusions: ", graph.getInclusions());

if preCollapseBlacklist {
    t.start();
    searchBlacklist(graph, "Pre-Collapse");
    t.stop();
    writeln("(Pre-Collapse) Blacklist Scan: ", t.elapsed(), " seconds...");
    t.clear();
}
if preCollapseMetrics {
    t.start();
    getMetrics(graph, "Pre-Collapse", preCollapseComponents);
    t.stop();
    writeln("(Pre-Collapse) Collected Metrics: ", t.elapsed());
    t.clear();
}

writeln("Collapsing HyperGraph...");
t.start();
var (vDupeHistogram, eDupeHistogram) = graph.collapse();
t.stop();
writeln("Collapsed Hypergraph: ", t.elapsed());
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
    t.clear();
}
if postCollapseMetrics {
    t.start();
    getMetrics(graph, "Post-Collapse", postCollapseComponents);
    t.stop();
    writeln("(Post-Collapse) Collected Metrics: ", t.elapsed(), " seconds...");
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

writeln("Printing out collapsed graph without isolated components...");
var ff = open("collapsed-hypergraph.txt", iomode.cw).writer();
forall e in graph.getEdges() {
    var str = graph.getProperty(e) + "\t";
    for v in graph.getNeighbors(e) {
        str += graph.getProperty(v) + ",";
    }
    ff.writeln(str[1..#(str.size - 1)]);
}

writeln("Printing out components of collapsed graph without isolated components...");
var fff = open("collapsed-hypergraph-components.txt", iomode.cw).writer();
for s in 1..3 {
    fff.writeln("Vertex Connected Components (s = ", s, "): ");
    var numComponents = 1;
    for vc in getVertexComponents(graph, s) {
        fff.writeln("\tComponent #", numComponents);
        numComponents += 1;
        for v in vc {
            fff.writeln("\t\t", graph.getProperty(v));
        }
    }
    fff.flush();
    
    fff.writeln("Edge Connected Components (s = ", s, "): ");
    numComponents = 1;
    for ec in getEdgeComponents(graph, s) {
        fff.writeln("\tComponent #", numComponents);
        numComponents += 1;
        for e in ec {
            fff.writeln("\t\t", graph.getProperty(e));
        }
    }
    fff.flush();
}

f.close();
ff.close();
fff.close();

writeln("Finished in ", tt.elapsed(), " seconds...");