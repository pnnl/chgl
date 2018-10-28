use Utilities;
use PropertyMap;
use AdjListHyperGraph;
use Time;
use Regexp;
use WorkQueue;
use Metrics;
use Components;

config const dataset = "../../data/DNS-Test-Data.csv";
config const dnsRegex = "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$";
config const preCollapseMetrics = false;

var dnsRegexp = compile(dnsRegex);
var f = open("metrics.txt", iomode.cw).writer();
var t = new Timer();
var wq = new WorkQueue(string);

writeln("Constructing PropertyMap...");
t.start();
var propMap = new PropertyMap(string, string);
var done : atomic bool;
var lines : atomic int;
begin {
    for line in readCSV(dataset) {
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
            var reg = rdata.matches(dnsRegexp);
            if reg.size != 0 {
                propMap.addVertexProperty(qname);
                propMap.addEdgeProperty(rdata);
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
    for line in readCSV(dataset) {
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
            
            var reg = rdata.matches(dnsRegexp);
            if reg.size != 0 {
                graph.addInclusion(propMap.getVertexProperty(qname), propMap.getEdgeProperty(rdata));
            }
        }
    }
}

t.stop();
writeln("Hypergraph Construction: ", t.elapsed());
t.clear();

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
    for s in 1..2 {
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
graph.collapse();
t.stop();
writeln("Collapsed Hypergraph: ", t.elapsed());
t.clear();

writeln("Number of Inclusions: ", graph.getInclusions());

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
for s in 1..2 {
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
graph.removeIsolatedComponents();
t.stop();
writeln("Removed isolated components: ", t.elapsed());
t.clear();

writeln("Number of Inclusions: ", graph.getInclusions());

forall v in graph.getVertices() {
    assert(graph.getVertex(v) != nil, "Vertex ", v, " is nil...");
    assert(graph.numNeighbors(v) > 0, "Vertex has 0 neighbors...");
    forall e in graph.getNeighbors(v) {
        assert(graph.getEdge(e) != nil, "Edge ", e, " is nil...");
        assert(graph.numNeighbors(e) > 0, "Edge has 0 neighbors...");

        var isValid : bool;
        for vv in graph.getNeighbors(e) {
            if vv == v {
                isValid = true;
                break;
            }
        }

        assert(isValid, "Vertex ", v, " has neighbor ", e, " that violates dual property...");
    }
}

forall e in graph.getEdges() {
    assert(graph.getEdge(e) != nil, "Edge ", e, " is nil...");
    assert(graph.numNeighbors(e) > 0, "Edge has 0 neighbors...");
    forall v in graph.getNeighbors(e) {
        assert(graph.getVertex(v) != nil, "Vertex ", v, " is nil...");
        assert(graph.numNeighbors(v) > 0, "Vertex has 0 neighbors...");

        var isValid : bool;
        for ee in graph.getNeighbors(v) {
            if ee == e {
                isValid = true;
                break;
            }
        }

        assert(isValid, "Edge ", e, " has neighbor ", v, " that violates dual property...");
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
for s in 1..2 {
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