proc vertexDegreeDistribution(graph) {
    var maxDeg = max reduce [v in graph.getVertices()] graph.numNeighbors(v);
    var degreeDist : [1..maxDeg] int;
    for v in graph.getVertices() do degreeDist[graph.numNeighbors(v)] += 1;
    return degreeDist;
}

proc edgeDegreeDistribution(graph) {
    var maxDeg = max reduce [v in graph.getEdges()] graph.numNeighbors(v);
    var degreeDist : [1..maxDeg] int;
    for v in graph.getEdges() do degreeDist[graph.numNeighbors(v)] += 1;
    return degreeDist;
}