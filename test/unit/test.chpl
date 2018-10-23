use Utilities;
use PropertyMap;

var propMap = new PropertyMap(string, string);
forall line in readCSV("../../data/DNS-Test-Data.csv") {
    var attrs = line.split("\t");
    var qname = attrs[2];
    var rdata = attrs[4];
    propMap.addVertexProperty(qname);
    propMap.addEdgeProperty(rdata);
}

writeln(propMap.vPropMap.dom);