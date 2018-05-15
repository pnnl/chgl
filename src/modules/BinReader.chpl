use IO;
use Sort;
use AdjListHyperGraph;

var inputFile = open("../../baylor-nodupes.bin", iomode.r, style = new iostyle(binary=1));
var inputFileReader = inputFile.reader();

// Read in |V| and |E|
var numVertices : uint(64);
var numEdges : uint(64);
inputFileReader.read(numVertices);
inputFileReader.read(numEdges);
writeln("|V| = " + numVertices);
writeln("|E| = " + numEdges);
inputFileReader.close();
inputFile.close();

// Construct graph (distributed)
const vertex_domain = {0..#numVertices:int} dmapped Cyclic(startIdx=0);
const edge_domain = {0..#numEdges:int} dmapped Cyclic(startIdx=0);
var graph = new AdjListHyperGraph(vertices_dom = vertex_domain, edges_dom = edge_domain);

// Beginning offset of adjacency list for each vertex and edge...
var vertexOffsets : [vertex_domain] uint(64);
var edgeOffsets : [edge_domain] uint(64);

// On each node, independently process the file and offsets...
coforall loc in Locales do on loc {
  // Obtain offset for indices that are local to each node...
  forall idx in vertexOffsets.localSubdomain() {
    // Open file again and skip to portion of file we want...
    var file = open("../../baylor-nodupes.bin", iomode.r, style = new iostyle(binary=1));
    var reader = file.reader();
    reader.advance(16 + (idx - 1) * 8);

    // Read our beginning offset...
    var beginOffset : uint(64);
    var endOffset : uint(64);
    reader.read(beginOffset);

    // Compute the ending offset... since the ending is the next offset minus one,
    // we can just read it from the file and avoid unnecessary communication with
    // other nodes. However if the idx is at the end of the array, we need to
    // make the endOffset the end of the array.
    if idx == (numEdges + numVertices) {
      endOffset = numVertices * 8;
    } else {
      endOffset = reader.read(endOffset);
    }
    endOffset -= 1:uint;

    // Advance to current idx's offset...
    var skip = (((numVertices + numEdges) - (idx + 1):uint) + beginOffset) * 8;
    reader.advance(skip:int);

    // TODO: Request storage space in advance for graph...
    // Read in adjacency list for edges... Since 'add_inclusion' already push_back
    // for the matching vertices and edges, we only need to do this once.
    for beginOffset..endOffset {
      var edge : uint(64);
      reader.read(edge);
      graph.add_inclusion(idx, edge);
    }
  }
}

/*
var verticesRange = 0..#numVertices;
var vertexStart = vertexOffsets[..maxVertexIdx];
var vertexEnd = vertexOffsets[1..];
vertexEnd.push_back(vertex_domain.high * 8);
for (vertex, start, end) in zip(verticesRange, vertexStart, vertexEnd) {
  for pos in (start..#end) {
    graph.vertices(vertex).push_back(data[pos]);
  }
}

var edgesRange = 1..#numEdges;
var edgeStart = edgeOffsets[..maxEdgeIdx];
var edgeEnd = edgeOffsets[1..];
edgeEnd.push_back(edge_domain.high * 8);
forall (edge, start, end) in zip(edgesRange, edgeStart, edgeEnd) {
  for pos in start..end {
    graph.edges(edge).push_back(data[pos]);
  }
} */
