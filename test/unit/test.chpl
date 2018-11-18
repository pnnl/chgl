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
config const outputDirectory = "tmp/";
config const metricsOutput = outputDirectory + "metrics.txt";
config const componentsOutput = outputDirectory + "collapsed-hypergraph-components.txt";
config const hypergraphOutput = outputDirectory + "collapsed-hypergraph.txt";
config const badDNSNamesRegex = "^[a-zA-Z]{4,5}\\.(pw|us|club|info|site|top)$";
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
var masterPropertyMap = EmptyPropertyMap;
var f = open(metricsOutput, iomode.cw).writer();
var t = new Timer();
var tt = new Timer();
var files : [0..-1] string;
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
    forall v in graph.getVertices() {
        var ip = graph.getProperty(v);
        if badIPAddresses.member(ip) {
            if !exists(outputDirectory + prefix) {
                try { 
                    mkdir(outputDirectory + prefix);
                }
                catch {

                }
            }
            var f = open(outputDirectory + prefix + "/" + ip, iomode.cw).writer();
            writeln("(" + prefix + ") Found blacklisted ip address ", ip);
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
    }
    forall e in graph.getEdges() {
        var dnsName = graph.getProperty(e);
        var isBadDNS = dnsName.matches(badDNSNamesRegexp);
        if badDNSNames.member(dnsName) || isBadDNS.size != 0 {
            if !exists(outputDirectory + prefix) {
                try {
                    mkdir(outputDirectory + prefix);
                }
                catch {

                }
            }
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
                for (ix, id) in zip(graph.edgesDomain, cachedComponents[s].cachedComponentMappings) {
                    if id == compId {
                        var ee = graph.toEdge(ix);
                        var str = "\t\t" + graph.getProperty(ee) + "\t";
                        for n in graph.incidence(ee) {
                            str += graph.getProperty(n) + ",";
                        }
                        f.writeln(str[..str.size - 1]);
                        f.flush();
                    }
                }
            }
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
    files.push_back(fileName);
    wq.addWork(datasetDirectory + fileName, currLoc % numLocales);
    currLoc += 1;
    nFiles += 1;
}
wq.flush();

// Initialize property maps
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
                    var attrs = line.split(",");
                    var qname = attrs[1];
                    var rdata = attrs[2];

                    propMap.addVertexProperty(rdata.strip());
                    propMap.addEdgeProperty(qname.strip());
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

writeln("Constructing HyperGraph...");
var graph = new AdjListHyperGraph(masterPropertyMap);

writeln("Adding inclusions to HyperGraph...");
// Fill work queue with files to load up
currLoc = 0;
nFiles = 0;
for fileName in files {    
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
              var attrs = line.split(",");
              var qname = attrs[1];
              var rdata = attrs[2];

              graph.addInclusion(masterPropertyMap.getVertexProperty(rdata.strip()), masterPropertyMap.getEdgeProperty(qname.strip()));
            }
        }
    }
}

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

t.start();
if !cachedComponentMappingsInitialized {
    for s in 1..3 do cachedComponents[s].cachedComponentMappings = getEdgeComponentMappings(graph, s);
    cachedComponentMappingsInitialized = true;
    writeln("(Post-Toplex) Generated Cache of Connected Components for 1..3 in ", t.elapsed(), " seconds...");
    f.writeln("Generated Post-Toplex Components: ", t.elapsed());
    t.clear();
}
getMetrics(graph, "Post-Toplex", true, cachedComponents);
t.stop();
writeln("(Post-Toplex) Collected Metrics: ", t.elapsed(), " seconds...");
f.writeln("Collected Post-Toplex Metrics: ", t.elapsed());
t.clear();


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

writeln("Printing out collapsed toplex graph...");
var ff = open(hypergraphOutput, iomode.cw).writer();
forall e in graph.getEdges() {
    var str = graph.getProperty(e) + "\t";
    for v in graph.incidence(e) {
        str += graph.getProperty(v) + ",";
    }
    ff.writeln(str[1..#(str.size - 1)]);
}

if !cachedComponentMappingsInitialized {
    for s in 1..3 do cachedComponents[s].cachedComponentMappings = getEdgeComponentMappings(graph, s);
    cachedComponentMappingsInitialized = true;
    writeln("(Post-Toplex) Generated Cache of Connected Components for 1..3 in ", t.elapsed(), " seconds...");
    f.writeln("Generated Components: ", t.elapsed());
    t.clear();
}

writeln("Printing out components of collapsed toplex graph...");
var fff = open(componentsOutput, iomode.cw).writer();
for s in 1..3 {
    var dom : domain(int);
    var arr : [dom] string;
    fff.writeln("Edge Connected Components (s = ", s, "): ");
    for (ix, id) in zip(graph.edgesDomain, cachedComponents[s].cachedComponentMappings) {
        var ee = graph.toEdge(ix);
        dom += id;
        ref str = arr[id];
        str += "\t\t" + graph.getProperty(ee) + "\t";
        for n in graph.incidence(ee) {
            str += graph.getProperty(n) + ",";
        }
        str = str[..str.size - 1] + "\n";
    }
    var numComponents = 1;
    for str in arr {
        fff.writeln("\tComponent #", numComponents, ":");
        fff.write(str);
        fff.flush();
        numComponents += 1;
    }
}

writeln("Finished in ", tt.elapsed(), " seconds...");
f.writeln("Finished in ", tt.elapsed(), " seconds...");
f.close();
ff.close();
fff.close();