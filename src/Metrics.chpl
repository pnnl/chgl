proc vertexDegreeDistribution(graph) {
    var maxDeg = max reduce [v in graph.getVertices()] graph.degree(graph.toVertex(v));
    var degreeDist : [1..maxDeg] int;
    for v in graph.getVertices() do degreeDist[graph.degree(v)] += 1;
    return degreeDist;
}

proc edgeDegreeDistribution(graph) {
    var maxDeg = max reduce [e in graph.getEdges()] graph.degree(graph.toEdge(e));
    var degreeDist : [1..maxDeg] int;
    for v in graph.getEdges() do degreeDist[graph.degree(v)] += 1;
    return degreeDist;
}

proc vertexComponentSizeDistribution(graph, s = 1) {
    var components = getVertexComponents(graph, s);
    var vComponentSizes = [vc in components] vc.size();
    var largestComponent = max reduce vComponentSizes;
    var componentSizes : [1..largestComponent] int;
    for vcSize in vComponentSizes do componentSizes[vcSize] += 1;
    delete components;
    return componentSizes;
}

proc edgeComponentSizeDistribution(graph, s = 1) {
    var componentMappings = getEdgeComponentMappings(graph, s);
    var componentsDom : domain(int);
    var components : [componentsDom] Vector(graph._value.eDescType);
    for (ix, id) in zip(componentMappings.domain, componentMappings) {
        componentsDom += id;
        if components[id] == nil {
            components[id] = new unmanaged VectorImpl(graph._value.eDescType, {0..-1});
        }
        arr[id].append(graph.toEdge(ix));
    }
    
    var eComponentSizes = [ec in components] ec.size();
    var largestComponent = max reduce eComponentSizes;
    delete components;

    var componentSizes : [1..largestComponent] int;
    for ecSize in eComponentSizes do componentSizes[ecSize] += 1;
    return componentSizes;
}
