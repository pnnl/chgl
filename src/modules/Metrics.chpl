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

proc vertexComponentSizeDistribution(graph, s = 1) {
    var vComponentSizes = [vc in getVertexComponents(graph, s)] vc.size();
    var largestComponent = max reduce vComponentSizes;
    var componentSizes : [1..largestComponent] int;
    for vcSize in vComponentSizes do componentSizes[vcSize] += 1;
    return componentSizes;
}

proc edgeComponentSizeDistribution(graph, s = 1) {
    var eComponentSizes = [ec in getEdgeComponents(graph, s)] ec.size();
    var largestComponent = max reduce eComponentSizes;
    var componentSizes : [1..largestComponent] int;
    for ecSize in eComponentSizes do componentSizes[ecSize] += 1;
    return componentSizes;
}