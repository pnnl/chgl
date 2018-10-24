use Utilities;
use PropertyMap;
use AdjListHyperGraph;

var propMap = new PropertyMap(string, string);
forall line in readCSV("../../data/DNS-Test-Data.csv") {
    var attrs = line.split("\t");
    var qname = attrs[2];
    var rdata = attrs[4];
    propMap.addVertexProperty(qname);
    propMap.addEdgeProperty(rdata);
}

var graph = new AdjListHyperGraph(propMap);
forall v in graph.getVertices() {
    writeln(v, " -> ", graph.getProperty(v));
}