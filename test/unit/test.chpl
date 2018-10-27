use Utilities;
use PropertyMap;
use AdjListHyperGraph;

writeln("Constructing PropertyMap...");
var propMap = new PropertyMap(string, string);
for line in readCSV("../../data/DNS-Test-Data.csv") {
    var attrs = line.split("\t");
    var qname = attrs[2];
    var rdata = attrs[4];
    propMap.addVertexProperty(qname);
    propMap.addEdgeProperty(rdata);
}

writeln("Constructing HyperGraph...");
var graph = new AdjListHyperGraph(propMap);

writeln("Adding inclusions to HyperGraph...");
for line in readCSV("../../data/DNS-Test-Data.csv") {
    var attrs = line.split("\t");
    var qname = attrs[2];
    var rdata = attrs[4];
    graph.addInclusion(propMap.getVertexProperty(qname), propMap.getEdgeProperty(rdata));
}

writeln("Number of Inclusions: ", graph.getInclusions());

writeln("Collapsing HyperGraph...");
graph.collapse();

writeln("Number of Inclusions: ", graph.getInclusions());

forall v in graph.getVertices() {
    assert(graph.getVertex(v) != nil, "Vertex ", v, " is nil...");
    assert(graph.numNeighbors(v) > 0, "Vertex has 0 neighbors...");
    forall e in graph.getNeighbors(v) {
        assert(graph.getEdge(e) != nil, "Edge ", e, " is nil...");
        assert(graph.numNeighbors(e) > 0, "Edge has 0 neighbors...");
    }
}

forall e in graph.getEdges() {
    assert(graph.getEdge(e) != nil, "Edge ", e, " is nil...");
    assert(graph.numNeighbors(e) > 0, "Edge has 0 neighbors...");
    forall v in graph.getNeighbors(e) {
        assert(graph.getVertex(v) != nil, "Vertex ", v, " is nil...");
        assert(graph.numNeighbors(v) > 0, "Vertex has 0 neighbors...");
    }
}

writeln("Removing isolated components...");
graph.removeIsolatedComponents();

writeln("Number of Inclusions: ", graph.getInclusions());

forall v in graph.getVertices() {
    assert(graph.getVertex(v) != nil, "Vertex ", v, " is nil...");
    assert(graph.numNeighbors(v) > 0, "Vertex has 0 neighbors...");
    forall e in graph.getNeighbors(v) {
        assert(graph.getEdge(e) != nil, "Edge ", e, " is nil...");
        assert(graph.numNeighbors(e) > 0, "Edge has 0 neighbors...");
    }
}

forall e in graph.getEdges() {
    assert(graph.getEdge(e) != nil, "Edge ", e, " is nil...");
    assert(graph.numNeighbors(e) > 0, "Edge has 0 neighbors...");
    forall v in graph.getNeighbors(e) {
        assert(graph.getVertex(v) != nil, "Vertex ", v, " is nil...");
        assert(graph.numNeighbors(v) > 0, "Vertex has 0 neighbors...");
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