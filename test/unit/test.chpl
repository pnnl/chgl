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

config const datasetDirectory = "../../data/DNS/";
config const badDNSNamesRegex = "^[a-zA-Z]{4,5}\\.(pw|us|club|info|site|top)$";
config const preCollapseMetrics = true;
config const doPreCollapseComponents = false;

var badDNSNamesRegexp = compile(badDNSNamesRegex);
var f = open("metrics.txt", iomode.cw).writer();
var t = new Timer();
var wq = new WorkQueue(string);

var badIPAddresses : domain(string);
var badDNSNames : domain(string);
for line in getLines("../../data/ip-most-wanted.txt") {
    badIPAddresses += line;
}
for line in getLines("../../data/dns-most-wanted.txt") {
    badDNSNames += line;
}

proc getMetrics(graph, prefix, components = true) {
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
    if components then for s in 1..3 {
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
    forall v in graph.getVertices() {
        var ip = graph.getProperty(v);
        if badIPAddresses.member(ip) {
            var str : string;
            writeln("(" + prefix + ") Found blacklisted ip address ", ip);
            
            // Print out its local neighbors...
            str += "(" + prefix + ") Blacklisted IP Address: " + ip + "\n";
            for s in 1..3 {
                str += "\tLocal Neighborhood (s=" + s + "):\n";
                for neighbor in graph.walk(v, s) {
                    str += "\t\t" + graph.getProperty(neighbor) + "\t";
                    for n in graph.getNeighbors(neighbor) {
                        str += graph.getProperty(n) + ",";
                    }
                    str = str[..str.size - 2];
                    str += "\n";
                }
            }

            // Print out its component
            for s in 1..3 {
                str += "\tComponent (s=" + s + "):\n";
                for vv in vertexBFS(graph, v, s) {
                    str += "\t\t" + graph.getProperty(vv) + "\t";
                    for n in graph.getNeighbors(vv) {
                        str += graph.getProperty(n) + ",";
                    }
                    str = str[..str.size - 2];
                    str += "\n";
                }
            }
            f.writeln(str);
            f.flush();
        }
    }
    forall e in graph.getEdges() {
        var dnsName = graph.getProperty(e);
        var isBadDNS = dnsName.matches(badDNSNamesRegexp);
        if badDNSNames.member(dnsName) || isBadDNS.size != 0 {
            var str : string;
            writeln("(" + prefix + ") Found blacklisted DNS Name ", dnsName);

            // Print out its local neighbors...
            str += "(" + prefix + ") Blacklisted DNS Name: " + dnsName + "\n";
            for s in 1..3 {
                str += "\tLocal Neighborhood (s=" + s + "):\n";
                for neighbor in graph.walk(e, s) {
                    str += "\t\t" + graph.getProperty(neighbor) + "\t";
                    for n in graph.getNeighbors(neighbor) {
                        str += graph.getProperty(n) + ",";
                    }
                    str = str[..str.size - 2];
                    str += "\n";
                }
            }

            // Print out its component
            for s in 1..3 {
                str += "\tComponent (s=" + s + "):\n";
                for ee in edgeBFS(graph, e, s) {
                    str += "\t\t" + graph.getProperty(ee) + "\t";
                    for n in graph.getNeighbors(ee) {
                        str += graph.getProperty(n) + ",";
                    }
                    str = str[..str.size - 2];
                    str += "\n";
                }
            }
            f.writeln(str);
            f.flush();
        }
    }
    writeln("Finished searching for blacklisted IPs...");
}

writeln("Constructing PropertyMap...");
t.start();
// Fill work queue with files to load up
var currLoc : int; 
for fileName in listdir(datasetDirectory, dirs=false) {
    wq.addWork(datasetDirectory + fileName, currLoc % numLocales);
    currLoc += 1;
}
wq.flush();

// Initialize property maps
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
                var attrs = line.split(",");
                assert(attrs.size == 2, "Bad input! Not comma separated: ", line);
                var qname = attrs[1];
                var rdata = attrs[2];
                propMap.addVertexProperty(rdata);
                propMap.addEdgeProperty(qname);
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
var master = propertyMaps[0];
if numLocales > 1 {
    for loc in Locales do on loc {
        master.append(propertyMaps[0]);
    }
}

t.stop();
writeln("Reading Property Map: ", t.elapsed());
t.clear();

t.start();
writeln("Constructing HyperGraph...");
var graph = new AdjListHyperGraph(master);

writeln("Adding inclusions to HyperGraph...");
// Fill work queue with files to load up
currLoc = 0;
for fileName in listdir(datasetDirectory, dirs=false) {
    wq.addWork(datasetDirectory + fileName, currLoc % numLocales);
    currLoc += 1;
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
                var attrs = line.split(",");
                assert(attrs.size == 2, "Bad input! Not comma separated: ", line);
                var qname = attrs[1];
                var rdata = attrs[2];
                graph.addInclusion(master.getVertexProperty(rdata), master.getEdgeProperty(qname));
            }
        }
    }
}

t.stop();
writeln("Hypergraph Construction: ", t.elapsed());
t.clear();
writeln("Number of Inclusions: ", graph.getInclusions());

searchBlacklist(graph, "Pre-Collapse");

if preCollapseMetrics {
    t.start();
    getMetrics(graph, "Pre-Collapse", doPreCollapseComponents);
    t.stop();
    writeln("(Pre-Collapse) Collected Metrics (VDD, EDD, VCCD, ECCD): ", t.elapsed());
    t.clear();
}

writeln("Collapsing HyperGraph...");
t.start();
var (vDupeHistogram, eDupeHistogram) = graph.collapse();
t.stop();
writeln("Collapsed Hypergraph: ", t.elapsed());
t.clear();

writeln("Number of Inclusions: ", graph.getInclusions());

searchBlacklist(graph, "Post-Collapse");

f.writeln("Distribution of Duplicate Vertex Counts:");
for (deg, freq) in zip(vDupeHistogram.domain, vDupeHistogram) {
    if freq != 0 then f.writeln("\t", deg, ",", freq);
}
f.writeln("Distribution of Duplicate Edge Counts:");
for (deg, freq) in zip(eDupeHistogram.domain, eDupeHistogram) {
    if freq != 0 then f.writeln("\t", deg, ",", freq);
}

t.start();
getMetrics(graph, "Post-Collapse");
t.stop();
writeln("(Post-Collapse) Collected Metrics (VDD, EDD, VCCD, ECCD): ", t.elapsed());
t.clear();

writeln("Removing isolated components...");
t.start();
var numIsolatedComponents = graph.removeIsolatedComponents();
t.stop();
writeln("Removed isolated components: ", t.elapsed());
f.writeln("Isolated Components Removed: ", numIsolatedComponents);
t.clear();

writeln("Number of Inclusions: ", graph.getInclusions());

searchBlacklist(graph, "Post-Removal");

t.start();
getMetrics(graph, "Post-Removal");
t.stop();
writeln("(Post-Removal) Collected Metrics (VDD, EDD, VCCD, ECCD): ", t.elapsed());
t.clear();

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