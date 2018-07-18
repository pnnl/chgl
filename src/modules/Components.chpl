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
      // id -> componentID
      var vertexComponents : [verticesDomain] int;
      var edgeComponents : [edgesDomain] int;
      // current componentID 
      var component : int(64);
      // current # of components
      var numComponents : int(64);
      
      proc visit(vertex : vDescType, currentDepth : int(64), ref maxDepth : int(64)) {
        if (vertexComponents[vertex.id] == 0) {
          maxDepth = max(currentDepth, maxDepth);
          vertexComponents[vertex.id] = component;
          for edge in getNeighbors(vertex) { 
            visit(edge, currentDepth + 1, maxDepth);
          }
        }
      }

      proc visit(edge : eDescType, currentDepth : int(64), ref maxDepth : int(64)) {
        if (edgeComponents[edge.id] == 0) {
          maxDepth = max(currentDepth, maxDepth);
          edgeComponents[edge.id] = component;
          for vertex in getNeighbors(edge) { 
            visit(vertex, currentDepth + 1, maxDepth);
          }
        }
      }

      // Iterate over all vertices in graph, assigning components
      for vertex in getVertices() { 
        if vertexComponents[vertex.id] != 0 then continue;
        component += 1;
        var size : int(64);
        visit(vertex, 1, size);
        if size >= minSize then numComponents += 1;
      }

      for edge in getEdges() {
        if edgeComponents[edge.id] != 0 then continue;
        component += 1;
        var size : int(64);
        visit(edge, 1, size);
        if size >= minSize then numComponents += 1;
      }

      return numComponents;
    }

    proc AdjListHyperGraphImpl.maximalComponentSize() {
      // id -> componentID
      var vertexComponents : [verticesDomain] int;
      var edgeComponents : [edgesDomain] int;
      // current componentID 
      var component : int(64);
      // maximum # of components
      var maxComponents : int(64);
      
      proc visit(vertex : vDescType, currentDepth : int(64), ref maxDepth : int(64)) {
        if (vertexComponents[vertex.id] == 0) {
          maxDepth = max(currentDepth, maxDepth);
          vertexComponents[vertex.id] = component;
          for edge in getNeighbors(vertex) { 
            visit(edge, currentDepth + 1, maxDepth);
          }
        }
      }
      
      proc visit(edge : eDescType, currentDepth : int(64), ref maxDepth : int(64)) {
        if (edgeComponents[edge.id] == 0) {
          maxDepth = max(currentDepth, maxDepth);
          edgeComponents[edge.id] = component;
          for vertex in getNeighbors(edge) { 
            visit(vertex, currentDepth + 1, maxDepth);
          }
        }
      }

      // Iterate over all vertices in graph, assigning components
      for vertex in getVertices() { 
        if vertexComponents[vertex.id] != 0 then continue;
        component += 1;
        var size : int(64);
        visit(vertex, 1, size);
        maxComponents = max(size, maxComponents);
      }

      for edge in getEdges() {
        if edgeComponents[edge.id] != 0 then continue;
        component += 1;
        var size : int(64);
        visit(edge, 1, size);
        maxComponents = max(size, maxComponents);
      }

      return maxComponents;

    }
}
