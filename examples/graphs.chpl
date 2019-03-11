use CHGL;

// TODO: Need to improve visualize to output something hypergraph-like rather than bipartite...

/*
    Configuration file ('configFile') must be of the following format...

    The first line, the header, must contain the number of vertices, followed
    by a space, then the number of edges...

    [1-9]+ [1-9]+

    Followed by zero or more lines associating a vertex with an edge...

    [0-9]+ [0-9]+

    Example: 5 vertices, 5 edges...

    4 4
    0 1
    1 0
    2 2
    3 4
    4 3
*/
config const configFile = "graph_examples/bipartite";

writeln("Configuration File: ", configFile);
var f = open(configFile, iomode.r).reader();

// Read in header...
var tmp : string;
assert(f.readline(tmp));
var arr = tmp.split(' ');
var numVerts = arr[1] : int;
var numEdges = arr[2] : int;
var graph = new AdjListHyperGraph(numVerts, numEdges);
while f.readline(tmp) {
    if tmp == "" then continue;
    var arr = tmp.split(' ');
    var v = arr[1] : int;
    var e = arr[2] : int;
    graph.addInclusion(v, e);
}

visualize(graph);