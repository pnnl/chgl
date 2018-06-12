use IO;
use Sort;
use AdjListHyperGraph;
use Generation;
use IO.FormattedIO;


proc main() {
  var f = open("../../test/data-samples/condMatCL.csv", iomode.r);
  var r = f.reader();

  var vertices : [0..-1] int;
  var edges : [0..-1] int;
  
  for line in f.lines() {
    var (v,e) : 2 * int;
    var split = line.split(",");
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


  var graph = new AdjListHyperGraph(numVertices, numEdges);
  vertices -= 1;
  edges -= 1;
  for (v,e) in zip(vertices, edges) {
    graph.addInclusion(v,e);
  }

  var inclusions_to_add : int;

  for i in graph.getVertexDegrees(){
    inclusions_to_add += i;
  }

  writeln(inclusions_to_add);

  var test_graph = new AdjListHyperGraph(numVertices,numEdges);
  var clGraph = fast_hypergraph_chung_lu(test_graph, test_graph.verticesDomain, test_graph.edgesDomain, graph.getVertexDegrees(), graph.getEdgeDegrees(), inclusions_to_add);
  
  var output = open("./generatedCL_output.csv", iomode.cw);
  var writer = output.writer();

  for i in clGraph.getVertices(){
    for j in clGraph.vertex(i).neighborList{
      var s:string = "%i,%i".format(i,j.id);
      writer.writeln(s);
    }
  }




/*
  var input_ed_file = open("../../test/visual-verification/ChungLu-Test/INPUT_dseq_E_List.csv", iomode.cw);
  var input_vd_file = open("../../test/visual-verification/ChungLu-Test/INPUT_dseq_V_List.csv", iomode.cw);
  var output_ed_file = open("../../test/visual-verification/ChungLu-Test/OUTPUT_dseq_E_List.csv", iomode.cw);
  var output_vd_file = open("../../test/visual-verification/ChungLu-Test/OUTPUT_dseq_V_List.csv", iomode.cw);
  
  var writing_input_ed_file = input_ed_file.writer();
  var writing_input_vd_file = input_vd_file.writer();
  var writing_output_ed_file = output_ed_file.writer();
  var writing_output_vd_file = output_vd_file.writer();
  
  var input_ed = graph.getEdgeDegrees();
  var input_vd = graph.getVertexDegrees();
  var output_ed = clGraph.getEdgeDegrees();
  var output_vd = clGraph.getVertexDegrees();
  
  for i in 1..input_ed.size{
    writing_input_ed_file.writeln(input_ed[i]);
  }

  for i in 1..input_vd.size{
    writing_input_vd_file.writeln(input_vd[i]);
  }

  for i in 1..22015{
    //writeln(i);
    writing_output_ed_file.writeln(output_ed[i]);
  }

  for i in 1..16723{
    //writeln(i);
    writing_output_vd_file.writeln(output_vd[i]);
  }
*/
  writeln("Done");
}
