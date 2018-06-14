use IO;
use Sort;
use AdjListHyperGraph;
use Generation;
use Butterfly;

proc main() {
    var graph = fromAdjacencyList("../../data/condMat/condMat.txt", " ");
    var vertexMetamorphs: [0..115] real;
    
    var vm_file = open("../../data/condMatBTER/mpdBTER_V.csv", iomode.r).reader();
    for i in 0..115{
        vm_file.read(vertexMetamorphs);
    }
    writeln("Expected Metamorph: ", vertexMetamorphs);
    var test = graph.getVertexPerDegreeMetamorphosisCoefficients();
    writeln("Actual Metamorph: ", test);
    writeln(test.size);
    writeln("Done");
}
