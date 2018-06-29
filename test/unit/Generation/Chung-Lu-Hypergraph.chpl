use Math;
use AdjListHyperGraph;
use Random;
use Generation;


var graph = new AdjListHyperGraph(10,20);
var inclusions_to_add = 600;
var original_vertex_degrees = graph.getVertexDegrees();
var original_edge_degrees = graph.getEdgeDegrees();

forall e in 6..9{
       original_vertex_degrees[e] = 2;
}
forall e in 9..12{
       original_edge_degrees[e] = 2;
}

var count : int = 0;
var initial: int = 0;
for e in 0..count-1{
    for o in graph.getVertex(e).neighborList{
    	initial += 1;
    }
}
graph = generateChungLu(graph, graph.verticesDomain, graph.edgesDomain, original_vertex_degrees, original_edge_degrees, inclusions_to_add);

count = graph.numVertices;
var edgecount: int = 0;
forall e in 0..#count with (+ reduce edgecount) {
    //writeln(graph.vertices(e).neighborList);
    for o in graph.getVertex(e).neighborList {
    	edgecount += 1;
    }
}
writeln(edgecount > initial);
