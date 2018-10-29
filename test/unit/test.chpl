use Utilities;
use PropertyMap;
use AdjListHyperGraph;
use Time;
use Regexp;
use WorkQueue;
use Metrics;
use Components;
use Traversal;



config const dataset = "../../data/DNS-Test-Data.csv";
config const ValidIPRegex = "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$";
config const badDNSNamesRegex = "^[a-zA-Z]{4,5}\\.(pw|us|club|info|site|top)\\.$";
config const preCollapseMetrics = true;

var ValidIPRegexp = compile(ValidIPRegex);
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

proc searchBlacklist(graph, prefix) {
    // Scan for most wanted...
    writeln("(" + prefix + ") Searching for known offenders...");
    forall v in graph.getVertices() {
        var ip = graph.getProperty(v);
        if badIPAddresses.member(ip) {
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
        }
    }
    forall e in graph.getEdges() {
        var dnsName = graph.getProperty(e);
        var isBadDNS = dnsName.matches(badDNSNamesRegexp);
        if badDNSNames.member(dnsName) || isBadDNS.size != 0 {
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
        }
    }
}

writeln("Constructing PropertyMap...");
t.start();
var propMap = new PropertyMap(string, string);
var done : atomic bool;
var lines : atomic int;
begin {
    for line in getLines(dataset) {
        lines.add(1);
        wq.addWork(line);
    }
    wq.flush();
    done.write(true);
}

coforall loc in Locales do on loc {
    coforall tid in 1..here.maxTaskPar {
        while true {
            var (hasElt, line) = wq.getWork();
            if !hasElt {
                if lines.read() == 0 && done.read() {
                    break;
                }
                chpl_task_yield();
                continue;
            } else {
                lines.sub(1);
            }

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
}

t.stop();
writeln("Reading Property Map: ", t.elapsed());
t.clear();

t.start();
writeln("Constructing HyperGraph...");
var graph = new AdjListHyperGraph(propMap);

writeln("Adding inclusions to HyperGraph...");
done.write(false);
begin {
    for line in getLines(dataset) {
        lines.add(1);
        wq.addWork(line);
    }
    wq.flush();
    done.write(true);
}

coforall loc in Locales do on loc {
    coforall tid in 1..here.maxTaskPar {
        while true {
            var (hasElt, line) = wq.getWork();
            if !hasElt {
                if lines.read() == 0 && done.read() {
                    break;
                }
                chpl_task_yield();
                continue;
            } else {
                lines.sub(1);
            }

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
                    graph.addInclusion(propMap.getVertexProperty(ip), propMap.getEdgeProperty(qname));
                }
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
    f.writeln("(Pre-Collapse) #V = ", graph.numVertices);
    f.writeln("(Pre-Collapse) #E = ", graph.numEdges);
    f.flush();
    f.writeln("(Pre-Collapse) Vertex Degree Distribution:");
    {
        var vDeg = vertexDegreeDistribution(graph);
        for (deg, freq) in zip(vDeg.domain, vDeg) {
            if freq != 0 then f.writeln("\t", deg, ",", freq);
        }
    }
    f.flush();
    f.writeln("(Pre-Collapse) Edge Cardinality Distribution:");
    {
        var eDeg = edgeDegreeDistribution(graph);
        for (deg, freq) in zip(eDeg.domain, eDeg) {
            if freq != 0 then f.writeln("\t", deg, ",", freq);
        }
    }
    f.flush();
    for s in 1..3 {
        var vccStr : string;
        var eccStr : string;
        cobegin with (ref vccStr, ref eccStr) {
            {
                vccStr += "(Pre-Collapse) Vertex Connected Component Size Distribution (s = " + s + "):\n";
                var vComponentSizes = vertexComponentSizeDistribution(graph, s);
                for (sz, freq) in zip(vComponentSizes.domain, vComponentSizes) {
                    if freq != 0 then vccStr += "\t" + sz + "," + freq + "\n";
                }
            }
            {
                eccStr += "(Pre-Collapse) Edge Connected Component Size Distribution (s = " + s + "):\n";
                var eComponentSizes = edgeComponentSizeDistribution(graph, s);
                for (sz, freq) in zip(eComponentSizes.domain, eComponentSizes) {
                    if freq != 0 then eccStr += "\t" + sz + "," + freq + "\n";
                }
            }
        }
        f.writeln(vccStr);
        f.writeln(eccStr);
        f.flush();
    }
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
f.writeln("(Post-Collapse) #V = ", graph.numVertices);
f.writeln("(Post-Collapse) #E = ", graph.numEdges);
f.flush();
f.writeln("(Post-Collapse) Vertex Degree Distribution:");
{
    var vDeg = vertexDegreeDistribution(graph);
    for (deg, freq) in zip(vDeg.domain, vDeg) {
        if freq != 0 then f.writeln("\t", deg, ",", freq);
    }
}
f.flush();
f.writeln("(Post-Collapse) Edge Cardinality Distribution:");
{
    var eDeg = edgeDegreeDistribution(graph);
    for (deg, freq) in zip(eDeg.domain, eDeg) {
        if freq != 0 then f.writeln("\t", deg, ",", freq);
    }
}
f.flush();
for s in 1..3 {
    f.flush();
    f.writeln("(Post-Collapse) Vertex Connected Component Size Distribution (s = ", s, "):");
    {
        var vComponentSizes = vertexComponentSizeDistribution(graph, s);
        for (sz, freq) in zip(vComponentSizes.domain, vComponentSizes) {
            if freq != 0 then f.writeln("\t", sz, ",", freq);
        }
    }
    f.flush();
    f.writeln("(Post-Collapse) Edge Connected Component Size Distribution (s = ", s, "):");
    {
        var eComponentSizes = edgeComponentSizeDistribution(graph, s);
        for (sz, freq) in zip(eComponentSizes.domain, eComponentSizes) {
            if freq != 0 then f.writeln("\t", sz, ",", freq);
        }
    }
    f.flush();
}
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
f.writeln("(Post-Removal) #V = ", graph.numVertices);
f.writeln("(Post-Removal) #E = ", graph.numEdges);
f.flush();
f.writeln("(Post-Removal) Vertex Degree Distribution:");
{
    var vDeg = vertexDegreeDistribution(graph);
    for (deg, freq) in zip(vDeg.domain, vDeg) {
        if freq != 0 then f.writeln("\t", deg, ",", freq);
    }
}
f.flush();
f.writeln("(Post-Removal) Edge Cardinality Distribution:");
{
    var eDeg = edgeDegreeDistribution(graph);
    for (deg, freq) in zip(eDeg.domain, eDeg) {
        if freq != 0 then f.writeln("\t", deg, ",", freq);
    }
}
f.flush();
for s in 1..3 {
    f.flush();
    f.writeln("(Post-Removal) Vertex Connected Component Size Distribution (s = ", s, "):");
    {
        var vComponentSizes = vertexComponentSizeDistribution(graph, s);
        for (sz, freq) in zip(vComponentSizes.domain, vComponentSizes) {
            if freq != 0 then f.writeln("\t", sz, ",", freq);
        }
    }
    f.flush();
    f.writeln("(Post-Removal) Edge Connected Component Size Distribution (s = ", s, "):");
    {
        var eComponentSizes = edgeComponentSizeDistribution(graph, s);
        for (sz, freq) in zip(eComponentSizes.domain, eComponentSizes) {
            if freq != 0 then f.writeln("\t", sz, ",", freq);
        }
    }
    f.flush();
}
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