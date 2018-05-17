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
var initial: int = 0;
var count: int = 0;
for e in 0..count-1{
    for o in graph.vertices(e).neighborList{
    	initial += 1;
    }
}
var Vdom : domain(int) = {1..graph.vertices_dom.size};
var Edom : domain(int) = {1..graph.edges_dom.size};
graph = fast_hypergraph_chung_lu(graph, Vdom, Edom, original_vertex_degrees, original_edge_degrees, inclusions_to_add);
count = 0;
for e in graph.vertices{
    count += 1;
}
var edgecount: int = 0;
for e in 0..count-1{
    //writeln(graph.vertices(e).neighborList);
    for o in graph.vertices(e).neighborList{
    	edgecount += 1;
    }
}
writeln(edgecount > initial);
