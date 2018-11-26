module Components {
    use AdjListHyperGraph;
    use Vectors;
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
        if components[v.id] != 0 then continue;
        var sequence = new unmanaged VectorImpl(graph._value.vDescType, {0..-1});
        component += 1;
        components[v.id] = component;
        sequence.append(v);
        for vv in vertexBFS(graph, v, s) {
          assert(components[vv.id] == 0, "Already visited a vertex during BFS...", vv);
          components[vv.id] = component;
          sequence.append(vv);
        }
        yield sequence;
      }
    }

    iter getEdgeComponents(graph, s = 1) {
      // id -> componentID
      var components : [graph.edgesDomain] int;
      // current componentID 
      var component : int(64);

      for e in graph.getEdges() {
        if components[e.id] != 0 then continue;
        var sequence = new unmanaged VectorImpl(graph._value.eDescType, {0..-1});
        component += 1;
        components[e.id] = component;
        sequence.append(e);
        for ee in edgeBFS(graph, e, s) {
          assert(components[ee.id] == 0, "Already visited an edge during BFS...", ee);
          components[ee.id] = component;
          sequence.append(ee);
        }
        yield sequence;
      }
    }

    proc getEdgeComponentMappings(graph, s = 1) {
      var components : [graph.edgesDomain] atomic int;
      var componentId : atomic int;
      var numComponents : atomic int;
      
      // Set all componnet ids to be the maximum so that they are the lowest priority
      [component in components] component.write(max(int));
      forall e in graph.getEdges() with (var taskComponentId : int = -1) do if graph.degree(e) >= s {
        if taskComponentId == -1 {
          taskComponentId = componentId.fetchAdd(1);
        }

        var retid = visit(e, taskComponentId);
        if retid == taskComponentId {
          taskComponentId = -1;
          numComponents.add(1);
        }
      }

      proc visit(e : graph._value.eDescType, id) : int {
        var currId = id;
        while true {
          var eid = components[e.id].read();
          //writeln("Read component id: ", eid);
          // Higher priority, take this edge...
          if eid > currId && components[e.id].compareExchange(eid, currId) {
            // TODO: Optimize to not check s-connectivity until we know we haven't looked at that s-neighbor...
            label checkNeighbor while true {
              for n in graph.walk(e, s) {
                //writeln("Walking from ", e, " to ", n, " for id: ", currId);
                var retid = visit(n, currId);
                // We're helping another component...
                if retid != currId {
                  currId = retid;
                  //writeln("Current helping ", currId);
                  continue checkNeighbor;
                }
              }
              break;
            }
            return currId;
          } else if eid <= currId {
            // Great priority or we already explored this edge...
            return eid;
          }
        }
        halt("Somehow exited loop...");
      }

      return [component in components] if component.read() == max(int) then -1 else component.read();
    }
}
