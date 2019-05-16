use CHGL;

// TODO: Need to improve visualize to output something hypergraph-like rather than bipartite...

// Iterate to find pairs of edges we can travel to as well as the distance needed
iter distanceEdgeBFS(graph, e : graph._value.eDescType, s=1) : (graph._value.eDescType, int) {
  var explored : domain(int);
  var queue = new list((int, int));
  queue.push_back((e.id, 0));
  while queue.size != 0 {
    var (currE, currDist) = queue.pop_front();
    if explored.contains(currE) then continue;
    explored += currE;
    if e.id != currE then yield (graph.toEdge(currE), currDist);
    for ee in graph.walk(graph.toEdge(currE), s) {
      queue.push_back((ee.id, currDist + 1));
    }
  }
}

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

// Outputs out.dot
visualize(graph);

// Compute s-eccentricity for s=1 only...
var maxEccentricity : int;
forall e in graph.getEdges() with (max reduce maxEccentricity) {
    for (_e, dist) in distanceEdgeBFS(graph, e) do if _e.id != e.id {
        maxEccentricity = max(maxEccentricity, dist);
    }
}
writeln("s-eccentricity (s=1): ", maxEccentricity);


