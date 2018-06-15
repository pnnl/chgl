module Components {
    use AdjListHyperGraph;

    enum WrapperType { VertexWrapper, EdgeWrapper };

    /**
     * Iterate over all vertices in graph and count the number of components.
     *
     * @param graph AdjListHyperGraph to count components in
     * @return int total number of components
     */
    proc AdjListHyperGraphImpl.countComponents(minSize = 1) : int {
      // (id, type) -> componentID
      var componentsDomain : domain((int(64), WrapperType));
      var components : [componentsDomain] int(64);
      // current componentID 
      var component : int(64);
      // current # of components
      var numComponents : int(64);

      // Iterate over all vertices in graph, assigning components
      for vertex in getVertices() { 
        const key = (vertex.id, WrapperType.VertexWrapper);
        if componentsDomain.member(key) then continue; 
        component += 1;
        var size = visit(vertex, components, componentsDomain, component);
        if size >= minSize then numComponents += 1;
      }

      for edge in getEdges() {
        const key = (edge.id, WrapperType.EdgeWrapper);
        if componentsDomain.member(key) then continue;
        component += 1;
        var size = visit(edge, components, componentsDomain, component);
        if size >= minSize then numComponents += 1;
      }

      return numComponents;
    }

    proc AdjListHyperGraphImpl.maximalComponentSize() {
      // (id, type) -> componentID
      var componentsDomain : domain((int(64), WrapperType));
      var components : [componentsDomain] int(64);
      // current componentID 
      var component : int(64);
      // maximum # of components
      var maxComponents : int(64);

      // Iterate over all vertices in graph, assigning components
      for vertex in getVertices() { 
        const key = (vertex.id, WrapperType.VertexWrapper);
        if componentsDomain.member(key) then continue; 
        component += 1;
        var size = visit(vertex, components, componentsDomain, component);
        maxComponents = max(size, maxComponents);
      }

      for edge in getEdges() {
        const key = (edge.id, WrapperType.EdgeWrapper);
        if componentsDomain.member(key) then continue;
        component += 1;
        var size = visit(edge, components, componentsDomain, component);
        maxComponents = max(size, maxComponents);
      }

      return maxComponents;

    }

    /**
     * Visit current node, visit all of its neighbors, assign it to the given component
     *
     * @param vertex Vertex for current vertex
     * @param component int component ID to assign to visited vertices
     */
    proc AdjListHyperGraphImpl.visit(node, components, ref componentsDomain,  component : int(64)) {
      var maxDepth : int;
      proc visitRecursive(node, currentDepth) {
        const key = (node.id, if node.nodeType == Vertex then WrapperType.VertexWrapper else WrapperType.EdgeWrapper);   
        componentsDomain.add(key);
        if (components[key] == 0) {
          maxDepth = max(currentDepth, maxDepth);
          components[key] = component;
          for neighbor in getNeighbors(node) { 
            visitRecursive(neighbor, currentDepth + 1);
          }
        }
      }

      visitRecursive(node, 1);
      return maxDepth;
    }
}
