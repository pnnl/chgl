use IO;
use Sort;
use AdjListHyperGraph;
use Generation;
use Butterfly;

// Parameter to determine whether or not verbose debugging information is provided.
config param DEBUG_BIN_READER = false;

// Print debug messages
proc debug(args...?nArgs) where DEBUG_BIN_READER {
    writeln(args);
}

// NOP
proc debug(args...?nArgs) where !DEBUG_BIN_READER {}

// Reads a binary file, derived from the fileName, into a graph.
proc readFile(fileName : string) throws {
    var f = open(fileName, iomode.r, style = new iostyle(binary=1));
    var graph = readFile(f);
    f.close();
    return graph;
}

// Reads a binary file into a graph
proc readFile(f : file) throws {
    try! {
        var reader = f.reader();

        // Read in |V| and |E|
        var numVertices : uint(64);
        var numEdges : uint(64);
        reader.read(numVertices);
        reader.read(numEdges);
        debug("|V| = " + numVertices);
        debug("|E| = " + numEdges);
        reader.close();

        // Construct graph (distributed)
        const vertex_domain = {0..#numVertices:int} dmapped Cyclic(startIdx=0);
        const edge_domain = {0..#numEdges:int} dmapped Cyclic(startIdx=0);
        var graph = new AdjListHyperGraph(vertices_dom = vertex_domain, edges_dom = edge_domain);

        // Beginning offset of adjacency list for each vertex and edge...
        var vertexOffsets : [vertex_domain] uint(64);
        var edgeOffsets : [edge_domain] uint(64);

        // On each node, independently process the file and offsets...
        coforall loc in Locales do on loc {
            debug("Node #", here.id, " beginning to process localSubdomain ", vertexOffsets.localSubdomain());
            // Obtain offset for indices that are local to each node...
            forall idx in vertexOffsets.localSubdomain() {
                // Open file again and skip to portion of file we want...
                var reader = f.reader();
                reader.advance(16 + idx * 8);
                debug("Starting at file offset ", reader.offset(), " for offset table of idx #", idx);

                // Read our beginning and ending offset... since the ending is the next
                // offset minus one, we can just read it from the file and avoid
                // unnecessary communication with other nodes.
                var beginOffset : uint(64);
                var endOffset : uint(64);
                reader.read(beginOffset);
                reader.read(endOffset);
                endOffset -= 1:uint;
                debug("Offsets into adjacency list for idx #", idx, " are ", beginOffset..endOffset);

                // Advance to current idx's offset...
                var skip = (((numVertices + numEdges) - (idx + 1):uint) + beginOffset) * 8;
                reader.advance(skip:int);
                debug("Adjacency list offset begins at file offset ", reader.offset());


                // TODO: Request storage space in advance for graph...
                // Read in adjacency list for edges... Since 'addInclusion' already push_back
                // for the matching vertices and edges, we only need to do this once.
                for beginOffset..endOffset {
                    var edge : uint(64);
                    reader.read(edge);
                    graph.addInclusion(idx : int, (edge - numVertices) : int);
                    debug("Added inclusion for vertex #", idx, " and edge #", (edge - numVertices));
                }
                reader.close();
            }
        }
        return graph;
    }

}


proc main() {
    var f = open("../../test/visual-verification/BTER-Test/condMat.txt", iomode.r);
    var r = f.reader();
    var vertices : [0..-1] int;
    var edges : [0..-1] int;

    for line in f.lines() {
        var (v,e) : 2 * int;
        var split = line.split(" ");
        if line == "" then continue;
        vertices.push_back(split[1] : int);
        edges.push_back(split[2] : int);
    }

    var numEdges : int;
    var numVertices : int;
    for (v,e) in zip(vertices, edges) {
        numEdges = max(numEdges, e);
        numVertices = max(numVertices, v);
    }


    var graph = new AdjListHyperGraph({1..numVertices}, {1..numEdges});

    var numInclusions = 0 : int;

    for (v,e) in zip(vertices, edges) {
        numInclusions += 1;
        graph.addInclusion(v,e);
    }

    var vertexMetamorphs: [0..115] real;
    var vm_file = open("../../test/visual-verification/BTER-Test/mpd_V.csv", iomode.r).reader();
    for i in 0..115{
        vm_file.read(vertexMetamorphs);
    }

    var test = graph.getVertexPerDegreeMetamorphosisCoefficients();

    writeln(test.size);

    writeln("Done");
}
