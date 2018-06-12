module Components {
    use AdjListHyperGraph;

    enum WrapperType { VertexWrapper, EdgeWrapper };

    /**
     * Iterate over all vertices in graph and count the number of components.
     *
     * @param graph AdjListHyperGraph to count components in
     * @return int total number of components
     */
    proc AdjListHyperGraphImpl.countComponents() : int {
      // (id, type) -> componentID
      var componentsDomain : domain((int(64), WrapperType));
      var components : [componentsDomain] int(64);
      // current componentID and total number of components
      var component : int(64) = 0;

      // Iterate over all vertices in graph, assigning components
      for v in getVertices() { 
        component += 1;
        for neighbor in getNeighbors(toVertex(v))  { 
          visit(neighbor, components, componentsDomain, component);
        }
      }

      return component;
    }

    /**
     * Visit current node, visit all of its neighbors, assign it to the given component
     *
     * @param vertex Vertex for current vertex
     * @param component int component ID to assign to visited vertices
     */
    proc AdjListHyperGraphImpl.visit(node, components, ref componentsDomain,  component : int(64)) {
      const key = (node.id, if node.nodeType == Vertex then WrapperType.VertexWrapper else WrapperType.EdgeWrapper);   
      componentsDomain.add(key);
      if (components[key] == 0) {
            components[key] = component;
            for neighbor in getNeighbors(node) { 
                visit(neighbor, components, componentsDomain, component);
            }
        }
    }
}
