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

config const input = "/dev/null";
config const outputDirectory = "./";
config const metricsOutput = outputDirectory + "metrics.txt";
config const componentsOutput = outputDirectory + "components.txt";
config const badDNSNamesRegex = "^[a-zA-Z]{4,5}\\.(pw|us|club|info|site|top)$";

var badDNSNamesRegexp = compile(badDNSNamesRegex);
var propertyMap = new PropertyMap(string, string);
var badIPAddresses : domain(string);
var badDNSNames : domain(string);

// Create blacklist
for line in getLines("../../data/ip-most-wanted.txt") {
    badIPAddresses += line;
}
for line in getLines("../../data/dns-most-wanted.txt") {
    badDNSNames += line;
}

// Create property map
for line in getLines(input) {
    var attrs = line.split("\t");
    var dns = attrs[1].strip();
    var iplist = attrs[2].strip();
    
    propertyMap.addEdgeProperty(dns);
    for ip in iplist.split(",").strip() {
        propertyMap.addVertexProperty(ip);
    }
}

// Create hypergraph
var graph = new AdjListHyperGraph(propertyMap);
for line in getLines(input) {
    var attrs = line.split("\t");
    var dns = attrs[1].strip();
    var iplist = attrs[2].strip().split(",");
    forall ip in iplist {
        graph.addInclusion(propertyMap.getVertexProperty(ip), propertyMap.getEdgeProperty(dns));
    }
}

// Cached components to avoid its costly recalculation...
pragma "default intent is ref"
record CachedComponents {
    var cachedComponentMappingsDomain = graph.edgesDomain;
    var cachedComponentMappings : [cachedComponentMappingsDomain] int;    
}
var cachedComponents : [1..3] CachedComponents;
var cachedComponentMappingsInitialized = false;

for s in 1..3 {
    cachedComponents[s].cachedComponentMappings = getEdgeComponentMappings(graph, s);
}

var f = open(metricsOutput, iomode.cw).writer();
f.writeln("#V = ", graph.numVertices);
f.writeln("#E = ", graph.numEdges);
f.flush();
f.writeln("Vertex Degree Distribution:");
{
    var vDeg = vertexDegreeDistribution(graph);
    for (deg, freq) in zip(vDeg.domain, vDeg) {
        if freq != 0 then f.writeln("\t", deg, ",", freq);
    }
}
f.flush();
f.writeln("Edge Cardinality Distribution:");
{
    var eDeg = edgeDegreeDistribution(graph);
    for (deg, freq) in zip(eDeg.domain, eDeg) {
        if freq != 0 then f.writeln("\t", deg, ",", freq);
    }
}
f.flush();
for s in 1..3 {
    var componentMappings = cachedComponents[s].cachedComponentMappings;
    var componentsDom : domain(int);
    var components : [componentsDom] unmanaged Vector(graph._value.eDescType);
    for (ix, id) in zip(componentMappings.domain, componentMappings) {
        if id == -1 then continue;
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

    f.writeln("Vertex Connected Component Size Distribution (s = " + s + "):");
    for (sz, freq) in zip(vComponentSizes.domain, vComponentSizes) {
        if freq != 0 then f.writeln("\t" + sz + "," + freq);
    }
    f.flush();

    f.writeln("Edge Connected Component Size Distribution (s = " + s + "):");
    for (sz, freq) in zip(eComponentSizes.domain, eComponentSizes) {
        if freq != 0 then f.writeln("\t" + sz + "," + freq);
    }
    f.flush();
    delete components;
}

{
    // Scan for most wanted...
    writeln("Searching for known offenders...");
    forall e in graph.getEdges() {
        var dnsName = graph.getProperty(e);
        var isBadDNS = dnsName.matches(badDNSNamesRegexp);
        if badDNSNames.member(dnsName) || isBadDNS.size != 0 {
            if !exists(outputDirectory) {
                try {
                    mkdir(outputDirectory);
                }
                catch {

                }
            }
            var f = open(outputDirectory + "/" + dnsName, iomode.cw).writer();
            writeln("Found blacklisted DNS Name ", dnsName);
            
            // Print out its local neighbors...
            f.writeln("Blacklisted DNS Name: ", dnsName);
            for s in 1..3 {
                f.writeln("\tLocal Neighborhood (s=", s, "):");
                var set : domain(int);
                for neighbor in graph.walk(e, s) {
                    var str = "\t\t" + graph.getProperty(neighbor) + "\t";
                    for n in graph.incidence(neighbor) {
                        if !set.member(n.id) {
                            str += graph.getProperty(n) + ",";
                            set += n.id;
                        }
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
    writeln("Finished searching for blacklisted DNS Names...");
}

writeln("Printing out components of graph...");
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

writeln("Finished...");
f.close();
fff.close();