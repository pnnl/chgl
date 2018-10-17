use IO;
use Sort;
use AdjListHyperGraph;
use Generation;
use Butterfly;
use Metrics;

proc main() {
    var graph = fromAdjacencyList("../../data/condMat/condMat.txt", " ");
    var vertexDegreeDist : [graph.verticesDomain] int;
    for (v, deg) in zip(graph.getVertices(), vertexDegreeDist) {
        deg = graph.numNeighbors(v);
    }
    writeln("Have vDegreeDist, max vDeg is ", max reduce vertexDegreeDist);
    
    var edgeDegreeDist : [graph.edgesDomain] int;
    for (e, deg) in zip(graph.getEdges(), edgeDegreeDist) {
        deg = graph.numNeighbors(e);
    }
    writeln("Have eDegreeDist, max eDeg is ", max reduce edgeDegreeDist);
    
    var vertexPDMC = graph.getVertexPerDegreeMetamorphosisCoefficients();
    var edgePDMC = graph.getEdgePerDegreeMetamorphosisCoefficients();
    writeln("have vertexPDMC and edgePDMC");

    var newGraph = generateBTER(vertexDegreeDist, edgeDegreeDist, vertexPDMC, edgePDMC);
    writeln("have bter graph");
    {
        writeln(newGraph.removeDuplicates());
        var vertexDegreeDist = vertexDegreeDistribution(newGraph);
        writeln("Have synthetic vDegreeDist, max vDeg is ", max reduce vertexDegreeDist);
       
        var f = open("ddBTER_V.csv", iomode.cw).writer();
        for deg in vertexDegreeDist[1..] do f.writeln(if isnan(deg) then 0 else deg); 
        f.close();
        
        var edgeDegreeDist = edgeDegreeDistribution(newGraph);
        writeln("Have synthetic eDegreeDist, max eDeg is ", max reduce edgeDegreeDist);

        f = open("ddBTER_E.csv", iomode.cw).writer();
        for deg in edgeDegreeDist[1..] do f.writeln(if isnan(deg) then 0 else deg);
        f.close();
        
        f = open("mpdBTER_V.csv", iomode.cw).writer();
        for deg in newGraph.getVertexPerDegreeMetamorphosisCoefficients()[1..] do f.writeln(if isnan(deg) then 0 else deg);
        f.close();

        f = open("mpdBTER_E.csv", iomode.cw).writer();
        for deg in newGraph.getEdgePerDegreeMetamorphosisCoefficients()[1..] do f.writeln(if isnan(deg) then 0 else deg);
        f.close();
    }

}
