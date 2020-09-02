use IO;
use Sort;
use AdjListHyperGraphs;
use Graphs;
use RangeChunk;
use CyclicDist;
use SysCTypes;

// TODO: Read in the _entire_ adjacency list as a byte stream and then perform a direct memcpy into 
// to pre-allocated buffer! Significantly faster, and it is what UPC++ did and was multiple orders
// of magnitude faster!

// Parameter to determine whether or not verbose debugging information is provided.
config param DEBUG_BIN_READER = false;
config const numEdgesPresent = true;

// Reads a binary file into a graph
proc binToHypergraph(dataset : string) throws {
  try! {
    var f = open(dataset, iomode.r, style = new iostyle(binary=1));
    var reader = f.reader();

    // Read in |V| and |E|
    var numVertices : uint(64);
    var numEdges : uint(64);
    reader.read(numVertices);
    reader.read(numEdges);
    debug("|V| = " + numVertices);
    debug("|E| = " + numEdges);
    reader.close();
    f.close();

    // Construct graph (distributed)
    var graph = new AdjListHyperGraph(numVertices:int, numEdges:int, new Cyclic(startIdx=0));

    // On each node, independently process the file and offsets...
    coforall loc in Locales do on loc {
      var f = open(dataset, iomode.r, style = new iostyle(binary=1));    
      // Obtain offset for indices that are local to each node...
      var dom = graph.verticesDomain.localSubdomain();
      coforall chunk in chunks(dom.low..dom.high by dom.stride, here.maxTaskPar) {
        var reader = f.reader(locking=false);
        for idx in chunk {
          reader.mark();
          // Open file again and skip to portion of file we want...
          const headerOffset = if numEdgesPresent then 16 else 8;
          reader.advance(headerOffset + idx * 8);

          // Read our beginning and ending offset... since the ending is the next
          // offset minus one, we can just read it from the file and avoid
          // unnecessary communication with other nodes.
          var beginOffset : uint(64);
          var endOffset : uint(64);
          reader.read(beginOffset);
          reader.read(endOffset);
          endOffset -= 1;

          // Advance to current idx's offset...
          var skip = ((numVertices - idx:uint - 1:uint) + beginOffset) * 8;
          reader.advance(skip:int);

          // Pre-allocate buffer for vector and read directly into it
          var edges : [0..#(endOffset - beginOffset + 1)] int;
          reader.readBytes(c_ptrTo(edges[0]), ((endOffset - beginOffset + 1) * 8) : ssize_t);
          graph.addInclusionBuffered(idx, edges);
          reader.revert();
        }
      }
    }
    graph.flushBuffers();
    return graph;
  }
}

proc binToGraph(dataset : string) {
  try! {
    var f = open(dataset, iomode.r, style = new iostyle(binary=1));
    var reader = f.reader();

    // Read in |V| and |E|
    var numVertices : uint(64);
    var numEdges : uint(64);
    reader.read(numVertices);
    reader.read(numEdges);
    debug("|V| = " + numVertices);
    debug("|E| = " + numEdges);
    reader.close();
    f.close();

    // Construct graph (distributed)
    var graph = new Graph(numVertices:int, numEdges:int, new unmanaged Cyclic(startIdx = 0));

    // On each node, independently process the file and offsets...
    coforall loc in Locales do on loc {
      var f = open(dataset, iomode.r, style = new iostyle(binary=1));    
      // Obtain offset for indices that are local to each node...
      var dom = graph.verticesDomain.localSubdomain();
      coforall chunk in chunks(dom.low..dom.high by dom.stride, here.maxTaskPar) {
        var reader = f.reader(locking=false);
        for idx in chunk {
          reader.mark();
          // Open file again and skip to portion of file we want...
          const headerOffset = 16;
          reader.advance(headerOffset + idx * 8);

          // Read our beginning and ending offset... since the ending is the next
          // offset minus one, we can just read it from the file and avoid
          // unnecessary communication with other nodes.
          var beginOffset : uint(64);
          var endOffset : uint(64);
          reader.read(beginOffset);
          reader.read(endOffset);
          endOffset -= 1;

          // Advance to current idx's offset...
          var skip = ((numVertices - idx:uint - 1:uint) + beginOffset) * 8;
          reader.advance(skip:int);

          // Pre-allocate buffer for vector and read directly into it
          var vertices : [0..#(endOffset - beginOffset + 1)] uint(64);
          reader.readBytes(c_ptrTo(vertices[0]), ((endOffset - beginOffset + 1) * 8) : ssize_t);
          for v in vertices do if idx < v then graph.addEdge(idx, v : int);
          reader.revert();
        }
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
