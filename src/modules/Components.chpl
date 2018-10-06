module Components {
    use AdjListHyperGraph;
    use Vector;
    use Traversal;

    /**
     * Iterate over all vertices in graph and count the number of components.
     *
     * @param graph AdjListHyperGraph to count components in
     * @return int total number of components
     */
    iter getVertexComponents(graph, s = 1) {
      // id -> componentID
      var components : [graph.verticesDomain] int;
      // current componentID 
      var component : int(64);

      for v in graph.getVertices() {
        var sequence = new owned Vector(graph._value.vDescType);
        if components[v.id] != 0 then continue;
        components[v.id] = component;
        sequence.append(v);
        for vv in vertexBFS(graph, v, s) {
          if components[vv.id] != 0 {
            components[vv.id] = component;
            sequence.append(components);
          }
        }
        yield sequence;
      }
    }

    iter getEdgeComponents(graph, s = 1) {
      // id -> componentID
      var components : [graph.edgesDomain] int;
      // current componentID 
      var component : int(64);

      for v in graph.getEdge() {
        var sequence = new owned Vector(graph._value.eDescType);
        if components[e.id] != 0 then continue;
        components[e.id] = component;
        sequence.append(e);
        for ee in edgeBFS(graph, e, s) {
          if components[ee.id] != 0 {
            components[ee.id] = component;
            sequence.append(components);
          }
        }
        yield sequence;
      }
    }
}
