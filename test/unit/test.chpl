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
config const badDNSNamesRegex = "[a-zA-Z]{4,5}\\.[pw|us|club|info|site|top]\\.";
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

// Scan for most wanted...
writeln("Searching for known offenders...");
forall v in graph.getVertices() {
    var ip = graph.getProperty(v);
    if badIPAddresses.member(ip) {
        writeln("(Pre-Collapse) Found blacklisted ip address ", ip);
        
        // Print out its local neighbors...
        f.writeln("(Pre-Collapse) Blacklisted IP Address: ", ip);
        for s in 1..3 {
            f.writeln("\tLocal Neighborhood (s=", s, "):");
            for neighbor in graph.walk(v, s) {
                var neighborIP = graph.getProperty(neighbor);
                f.writeln("\t\t", neighborIP);
            }
            f.flush();
        }

        // Print out its component
        for s in 1..3 {
            f.writeln("\tComponent (s=", s, "):");
            for vv in vertexBFS(graph, v, s) {
                var componentIP = graph.getProperty(vv);
                f.writeln("\t\t", componentIP);
            }
        }
    }
}
forall e in graph.getEdges() {
    var dnsName = graph.getProperty(e);
    var isBadDNS = dnsName.matches(badDNSNamesRegexp);
    if badDNSNames.member(dnsName) || isBadDNS.size != 0 {
        writeln("(Pre-Collapse) Found blacklisted DNS Name ", dnsName);

        // Print out its local neighbors...
        f.writeln("(Pre-Collapse) Blacklisted DNS Name: ", dnsName);
        for s in 1..3 {
            f.writeln("\tLocal Neighborhood (s=", s, "):");
            for neighbor in graph.walk(e, s) {
                var neighborIP = graph.getProperty(neighbor);
                f.writeln("\t\t", neighborIP);
            }
            f.flush();
        }

        // Print out its component
        for s in 1..3 {
            f.writeln("\tComponent (s=", s, "):");
            for ee in edgeBFS(graph, e, s) {
                var componentIP = graph.getProperty(ee);
                f.writeln("\t\t", componentIP);
            }
        }
    }
}

writeln("Number of Inclusions: ", graph.getInclusions());

if preCollapseMetrics {
    t.start();
    f.writeln("(Pre-Collapse) #V = ", graph.numVertices);
    f.writeln("(Pre-Collapse) #E = ", graph.numEdges);
    f.flush();
    f.writeln("(Pre-Collapse) Vertex Degree Distribution");
    {
        var vDeg = vertexDegreeDistribution(graph);
        for (deg, freq) in zip(vDeg.domain, vDeg) {
            if freq != 0 then f.writeln("\t", deg, ",", freq);
        }
    }
    f.flush();
    f.writeln("(Pre-Collapse) Edge Cardinality Distribution");
    {
        var eDeg = edgeDegreeDistribution(graph);
        for (deg, freq) in zip(eDeg.domain, eDeg) {
            if freq != 0 then f.writeln("\t", deg, ",", freq);
        }
    }
    for s in 1..3 {
        f.flush();
        f.writeln("(Pre-Collapse) Vertex Connected Component Size Distribution (s = ", s, ")");
        {
            var vComponentSizes = vertexComponentSizeDistribution(graph, s);
            for (sz, freq) in zip(vComponentSizes.domain, vComponentSizes) {
                if freq != 0 then f.writeln("\t", sz, ",", freq);
            }
        }
        f.flush();
        f.writeln("(Pre-Collapse) Edge Connected Component Size Distribution (s = ", s, ")");
        {
            var eComponentSizes = edgeComponentSizeDistribution(graph, s);
            for (sz, freq) in zip(eComponentSizes.domain, eComponentSizes) {
                if freq != 0 then f.writeln("\t", sz, ",", freq);
            }
        }
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

// Scan for most wanted...
writeln("Searching for known offenders...");
forall v in graph.getVertices() {
    var ip = graph.getProperty(v);
    if badIPAddresses.member(ip) {
        writeln("(Post-Collapse) Found blacklisted ip address ", ip);
        
        // Print out its local neighbors...
        f.writeln("(Post-Collapse) Blacklisted IP Address: ", ip);
        for s in 1..3 {
            f.writeln("\tLocal Neighborhood (s=", s, "):");
            for neighbor in graph.walk(v, s) {
                var neighborIP = graph.getProperty(neighbor);
                f.writeln("\t\t", neighborIP);
            }
            f.flush();
        }

        // Print out its component
        for s in 1..3 {
            f.writeln("\tComponent (s=", s, "):");
            for vv in vertexBFS(graph, v, s) {
                var componentIP = graph.getProperty(vv);
                f.writeln("\t\t", componentIP);
            }
        }
    }
}
forall e in graph.getEdges() {
    var dnsName = graph.getProperty(e);
    var isBadDNS = dnsName.matches(badDNSNamesRegexp);
    if badDNSNames.member(dnsName) || isBadDNS.size != 0 {
        writeln("(Post-Collapse) Found blacklisted DNS Name ", dnsName);

        // Print out its local neighbors...
        f.writeln("(Post-Collapse) Blacklisted DNS Name: ", dnsName);
        for s in 1..3 {
            f.writeln("\tLocal Neighborhood (s=", s, "):");
            for neighbor in graph.walk(e, s) {
                var neighborIP = graph.getProperty(neighbor);
                f.writeln("\t\t", neighborIP);
            }
            f.flush();
        }

        // Print out its component
        for s in 1..3 {
            f.writeln("\tComponent (s=", s, "):");
            for ee in edgeBFS(graph, e, s) {
                var componentIP = graph.getProperty(ee);
                f.writeln("\t\t", componentIP);
            }
        }
    }
}

f.writeln("Distribution of Duplicate Vertex Counts");
for (deg, freq) in zip(vDupeHistogram.domain, vDupeHistogram) {
    if freq != 0 then f.writeln("\t", deg, ",", freq);
}
f.writeln("Distribution of Duplicate Edge Counts");
for (deg, freq) in zip(eDupeHistogram.domain, eDupeHistogram) {
    if freq != 0 then f.writeln("\t", deg, ",", freq);
}

t.start();
f.writeln("(Post-Collapse) #V = ", graph.numVertices);
f.writeln("(Post-Collapse) #E = ", graph.numEdges);
f.flush();
f.writeln("(Post-Collapse) Vertex Degree Distribution");
{
    var vDeg = vertexDegreeDistribution(graph);
    for (deg, freq) in zip(vDeg.domain, vDeg) {
        if freq != 0 then f.writeln("\t", deg, ",", freq);
    }
}
f.flush();
f.writeln("(Post-Collapse) Edge Cardinality Distribution");
{
    var eDeg = edgeDegreeDistribution(graph);
    for (deg, freq) in zip(eDeg.domain, eDeg) {
        if freq != 0 then f.writeln("\t", deg, ",", freq);
    }
}
f.flush();
for s in 1..3 {
    f.flush();
    f.writeln("(Post-Collapse) Vertex Connected Component Size Distribution (s = ", s, ")");
    {
        var vComponentSizes = vertexComponentSizeDistribution(graph, s);
        for (sz, freq) in zip(vComponentSizes.domain, vComponentSizes) {
            if freq != 0 then f.writeln("\t", sz, ",", freq);
        }
    }
    f.flush();
    f.writeln("(Post-Collapse) Edge Connected Component Size Distribution (s = ", s, ")");
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

// Scan for most wanted...
writeln("Searching for known offenders...");
forall v in graph.getVertices() {
    var ip = graph.getProperty(v);
    if badIPAddresses.member(ip) {
        writeln("(Post-Removals) Found blacklisted ip address ", ip);
        
        // Print out its local neighbors...
        f.writeln("(Post-Removal) Blacklisted IP Address: ", ip);
        for s in 1..3 {
            f.writeln("\tLocal Neighborhood (s=", s, "):");
            for neighbor in graph.walk(v, s) {
                var neighborIP = graph.getProperty(neighbor);
                f.writeln("\t\t", neighborIP);
            }
            f.flush();
        }

        // Print out its component
        for s in 1..3 {
            f.writeln("\tComponent (s=", s, "):");
            for vv in vertexBFS(graph, v, s) {
                var componentIP = graph.getProperty(vv);
                f.writeln("\t\t", componentIP);
            }
        }
    }
}
forall e in graph.getEdges() {
    var dnsName = graph.getProperty(e);
    var isBadDNS = dnsName.matches(badDNSNamesRegexp);
    if badDNSNames.member(dnsName) || isBadDNS.size != 0 {
        writeln("(Post-Removal) Found blacklisted DNS Name ", dnsName);

        // Print out its local neighbors...
        f.writeln("(Post-Removal) Blacklisted DNS Name: ", dnsName);
        for s in 1..3 {
            f.writeln("\tLocal Neighborhood (s=", s, "):");
            for neighbor in graph.walk(e, s) {
                var neighborIP = graph.getProperty(neighbor);
                f.writeln("\t\t", neighborIP);
            }
            f.flush();
        }

        // Print out its component
        for s in 1..3 {
            f.writeln("\tComponent (s=", s, "):");
            for ee in edgeBFS(graph, e, s) {
                var componentIP = graph.getProperty(ee);
                f.writeln("\t\t", componentIP);
            }
        }
    }
}

t.start();
f.writeln("(Post-Removal) #V = ", graph.numVertices);
f.writeln("(Post-Removal) #E = ", graph.numEdges);
f.flush();
f.writeln("(Post-Removal) Vertex Degree Distribution");
{
    var vDeg = vertexDegreeDistribution(graph);
    for (deg, freq) in zip(vDeg.domain, vDeg) {
        if freq != 0 then f.writeln("\t", deg, ",", freq);
    }
}
f.flush();
f.writeln("(Post-Removal) Edge Cardinality Distribution");
{
    var eDeg = edgeDegreeDistribution(graph);
    for (deg, freq) in zip(eDeg.domain, eDeg) {
        if freq != 0 then f.writeln("\t", deg, ",", freq);
    }
}
f.flush();
for s in 1..3 {
    f.flush();
    f.writeln("(Post-Removal) Vertex Connected Component Size Distribution (s = ", s, ")");
    {
        var vComponentSizes = vertexComponentSizeDistribution(graph, s);
        for (sz, freq) in zip(vComponentSizes.domain, vComponentSizes) {
            if freq != 0 then f.writeln("\t", sz, ",", freq);
        }
    }
    f.flush();
    f.writeln("(Post-Removal) Edge Connected Component Size Distribution (s = ", s, ")");
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

writeln("Printing out inclusions...");
var ff = open("collapsed-hypergraph.txt", iomode.cw).writer();
forall e in graph.getEdges() {
    var str = graph.getProperty(e) + "\t";
    for v in graph.getNeighbors(e) {
        str += graph.getProperty(v) + ",";
    }
    ff.writeln(str[1..#(str.size - 1)]);
}