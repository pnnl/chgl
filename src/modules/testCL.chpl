use IO;
use Sort;
use AdjListHyperGraph;
use Generation;

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
        // Read in adjacency list for edges... Since 'add_inclusion' already push_back
        // for the matching vertices and edges, we only need to do this once.
        for beginOffset..endOffset {
          var edge : uint(64);
          reader.read(edge);
          graph.add_inclusion(idx : int, (edge - numVertices) : int);
          debug("Added inclusion for vertex #", idx, " and edge #", (edge - numVertices));
        }
        reader.close();
      }
    }
    return graph;
  }

}


proc main() {
  var graph = readFile("../../condMat.bin");

  var clGraph = fast_hypergraph_chung_lu(graph, graph.verticesDomain, graph.edgesDomain, graph.getVertexDegrees(), graph.getEdgeDegrees(), 1);

  var input_ed_file = open("./INPUT_dseq_E_List.csv", iomode.cw);
  var input_vd_file = open("./INPUT_dseq_V_List.csv", iomode.cw);
  var output_ed_file = open("./OUTPUT_dseq_E_List.csv", iomode.cw);
  var output_vd_file = open("./OUTPUT_dseq_V_List.csv", iomode.cw);
  
  var writing_input_ed_file = input_ed_file.writer();
  var writing_input_vd_file = input_vd_file.writer();
  var writing_output_ed_file = output_ed_file.writer();
  var writing_output_vd_file = output_vd_file.writer();
  
  var input_ed = graph.getEdgeDegrees();
  var input_vd = graph.getVertexDegrees();
  var output_ed = clGraph.getEdgeDegrees();
  var input_vd = clGraph.getVertexDegrees();
  
  for i in 1..input_ed.size{
    writing_input_ed_file.writeln(input_ed[i]);
  }

  for i in 1..input_vd.size{
    writing_input_vd_file.writeln(input_vd[i]);
  }

  for i in 1..output_ed.size{
    writing_output_ed_file.writeln(output_ed[i]);
  }

  for i in 1..output_vd.size{
    writing_output_vd_file.writeln(output_vd[i]);
  }

  writeln("Done");
}
