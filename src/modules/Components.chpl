module Components {
    use AdjListHyperGraph;

    /**
     * Iterate over all vertices in graph and count the number of components.
     *
     * @param graph AdjListHyperGraph to count components in
     * @return int total number of components
     */
    proc countComponents(graph : AdjListHyperGraph) : int {
        // associative array (domain) of vertex to int component ID, surely
        // there's a more memory efficient way...
        var componentsDomain : domain(int(64)) = {0..-1};
        var components : [componentsDomain] int(64);
        // current component ID and total number of components
        var component : int(64) = 0;

        // Bootstrap the components associative domain, setting all to zero (no component assigned)
        for vertex in graph.vertices {
            for neighbor in vertex.neighborList { // FIXME improve graph iteration
                componentsDomain.add(neighbor.id);
                components[neighbor.id] = component;
            }
        }

        // Iterate over all vertices in graph, assigning components
        for vertex in graph.vertices { // TODO forall
            component += 1;
            for neighbor in vertex.neighborList { // FIXME improve graph iteration
                visitVertex(graph, neighbor, components, component);
            }
        }

        return component;
    }

    /**
     * Visit a vertex, visit all of its neighbors, assign it to the given component
     *
     * @param vertex Vertex for current vertex
     * @param component int component ID to assign to visited vertices
     */
    proc visitVertex(graph, vertex : Wrapper, components, component : int(64)) {
        if (components[vertex.id] == 0) {
            components[vertex.id] = component;
            forall neighbor in graph.inclusions(vertex) { // TODO forall
                visitVertex(graph, neighbor, components, component);
            }
        }
    }
}
