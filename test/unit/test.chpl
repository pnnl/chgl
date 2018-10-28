use Utilities;
use PropertyMap;
use AdjListHyperGraph;
use Time;
use Regexp;
use WorkQueue;

config const dataset = "../../data/DNS-Test-Data.csv";
config const dnsRegex = "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$";
var dnsRegexp = compile(dnsRegex);

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

writeln("Collapsing HyperGraph...");
t.start();
graph.collapse();
t.stop();
writeln("Collapsed Hypergraph: ", t.elapsed());
t.clear();

writeln("Number of Inclusions: ", graph.getInclusions());

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

writeln("Printing out inclusions...");
var f = open("collapsed-hypergraph.txt", iomode.cw).writer();
forall e in graph.getEdges() {
    var str = graph.getProperty(e) + "\t";
    for v in graph.getNeighbors(e) {
        str += graph.getProperty(v) + ",";
    }
    f.writeln(str[1..#(str.size - 1)]);
}