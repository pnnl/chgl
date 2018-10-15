use IO;
use Sort;
use AdjListHyperGraph;
use Generation;
use Butterfly;

proc main() {
    var graph = fromAdjacencyList("../../data/condMat/condMat.txt", " ");
    var vertexDegreeDist : [graph.verticesDomain] int;
    for (v, deg) in zip(graph.getVertices(), vertexDegreeDist) {
        deg = graph.numNeighbors(v);
    }
    writeln("Have vDegreeDist");
    var edgeDegreeDist : [graph.edgesDomain] int;
    for (e, deg) in zip(graph.getEdges(), edgeDegreeDist) {
        deg = graph.numNeighbors(e);
    }
    writeln("Have eDegreeDist");
    var vertexPDMC = graph.getVertexPerDegreeMetamorphosisCoefficients();
    var edgePDMC = graph.getEdgePerDegreeMetamorphosisCoefficients();
    writeln("have vertexPDMC and edgePDMC");

    var newGraph = generateBTER(vertexDegreeDist, edgeDegreeDist, vertexPDMC, edgePDMC);
    
    writeln("have bter graph");
    {
        writeln(newGraph.removeDuplicates());
        var vertexDegreeDist : [newGraph.verticesDomain] int;
        for (v, deg) in zip(graph.getVertices(), vertexDegreeDist) {
            deg = newGraph.numNeighbors(v);
        }
        writeln("Degree Dist: ", vertexDegreeDist);
        writeln("vertex PDMC: ", newGraph.getVertexPerDegreeMetamorphosisCoefficients());
    }

}
