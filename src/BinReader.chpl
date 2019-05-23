use IO;
use Sort;
use AdjListHyperGraph;
use Graph;

// Parameter to determine whether or not verbose debugging information is provided.
config param DEBUG_BIN_READER = false;

// Print debug messages
proc debug(args...?nArgs) where DEBUG_BIN_READER {
  writeln(args);
}

// NOP
proc debug(args...?nArgs) where !DEBUG_BIN_READER {}

// Reads a binary file, derived from the fileName, into a graph.
proc binToHypergraph(fileName : string) throws {
  var f = open(fileName, iomode.r, style = new iostyle(binary=1));
  var graph = binToHypergraph(f);
  f.close();
  return graph;
}

// Reads a binary file, derived from the fileName, into a graph.
proc binToGraph(fileName : string) throws {
  var f = open(fileName, iomode.r, style = new iostyle(binary=1));
  var graph = binToGraph(f);
  f.close();
  return graph;
}

// Reads a binary file into a graph
proc binToHypergraph(f : file) throws {
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
    var graph = new AdjListHyperGraph(numVertices:int, numEdges:int, new Cyclic(startIdx=0));

    // Beginning offset of adjacency list for each vertex and edge...
    var vertexOffsets : [graph.verticesDomain] uint(64);
    var edgeOffsets : [graph.edgesDomain] uint(64);

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

proc binToGraph(f : file) {
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
    var graph = new Graph(numVertices:int, numEdges:int, new unmanaged Cyclic(startIdx = 0));

    // On each node, independently process the file and offsets...
    coforall loc in Locales do on loc {
      debug("Node #", here.id, " beginning to process localSubdomain ", graph.verticesDomain.localSubdomain());
      // Obtain offset for indices that are local to each node...
      forall idx in graph.verticesDomain.localSubdomain() {
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
        endOffset -= 1;
        debug("Offsets into adjacency list for idx #", idx, " are ", beginOffset..endOffset);

        // Advance to current idx's offset...
        var skip = ((numVertices - idx:uint - 1:uint) + beginOffset) * 8;
        reader.advance(skip:int);
        debug("Adjacency list offset begins at file offset ", reader.offset());


        // TODO: Request storage space in advance for graph...
        // Read in adjacency list for edges... Since 'addInclusion' already push_back
        // for the matching vertices and edges, we only need to do this once.
        for beginOffset : int..endOffset : int {
          var edge : uint(64);
          reader.read(edge);
          graph.addEdge(idx : int, edge : int);
          debug("Added inclusion for vertex #", idx, " and edge #", edge);
        }
        reader.close();
      }
    }
    graph.flush();
    return graph;
  }
}


proc main() {
  var graph = binToGraph("../data/karate.mtx_csr.bin");
  writeln("Vertices: ", graph.numVertices);
  writeln("Edges: ", graph.numEdges);
  writeln("Vertex Degrees: {");
  forall v in graph.getVertices() {
    writeln("\tdegree(", v.id, ") = ", graph.degree(v));
  }
  writeln("}");
}
