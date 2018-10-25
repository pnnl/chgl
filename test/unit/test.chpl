use Utilities;
use PropertyMap;
use AdjListHyperGraph;

writeln("Constructing PropertyMap...");
var propMap = new PropertyMap(string, string);
forall line in readCSV("../../data/DNS-Test-Data.csv") {
    var attrs = line.split("\t");
    var qname = attrs[2];
    var rdata = attrs[4];
    propMap.addVertexProperty(qname);
    propMap.addEdgeProperty(rdata);
}

writeln("Constructing HyperGraph...");
var graph = new AdjListHyperGraph(propMap);

writeln("Add inclusions to HyperGraph...");
forall line in readCSV("../../data/DNS-Test-Data.csv") {
    var attrs = line.split("\t");
    var qname = attrs[2];
    var rdata = attrs[4];
    graph.addInclusion(propMap.getVertexProperty(qname), propMap.getEdgeProperty(rdata));
}

writeln("Number of Inclusions: ", graph.getInclusions());

writeln("Collapsing HyperGraph...");
graph.collapse();

writeln("Number of Inclusions: ", graph.getInclusions());

writeln("Printing out inclusions...");
forall e in graph.getEdges() {
    write(graph.getProperty(e), "\t");
    for v in graph.getVertices() {
        writeln(graph.getProperty(v) + ",");
    }
    writeln();
}