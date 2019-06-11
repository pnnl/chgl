/*
  Compilation of common metrics to be performed on hypergraphs or graphs.
*/
use Metrics {
  use Vectors;
  use Traversal;

  /*
    Iterate over all vertices in graph and count the number of s-connected components.
    A s-connected component is a group of vertices that can be s-walked to. A vertex
    v can s-walk to a vertex v' if the intersection of both v and v' is at least s.

    :arg graph: Hypergraph or Graph to obtain the vertex components of.
    :arg s: Minimum s-connectivity.
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

  /*
    Iterate over all edges in graph and count the number of s-connected components.
    A s-connected component is a group of vertices that can be s-walked to. A edge
    e can s-walk to a edge e' if the intersection of both e and e' is at least s.

    :arg graph: Hypergraph or Graph to obtain the vertex components of.
    :arg s: Minimum s-connectivity.
  */
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
  
  /*
    Assigns hyperedges to components and assigns them component ids. Returns an array
    that is mapped over the same domain as the hypergraph or graph.

    :arg graph: Hypergraph or graph.
    :arg s: Minimum s-connectivity.
  */
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

  /*
    Obtain the degree distribution of vertices as a histogram.
    
    :arg graph: Hypergraph or graph.
  */
  proc vertexDegreeDistribution(graph) {
    var maxDeg = max reduce [v in graph.getVertices()] graph.degree(graph.toVertex(v));
    var degreeDist : [1..maxDeg] int;
    for v in graph.getVertices() do degreeDist[graph.degree(v)] += 1;
    return degreeDist;
  }

  /*
    Obtain the degree distribution of edges as a histogram.
    
    :arg graph: Hypergraph or graph.
  */
  proc edgeDegreeDistribution(graph) {
    var maxDeg = max reduce [e in graph.getEdges()] graph.degree(graph.toEdge(e));
    var degreeDist : [1..maxDeg] int;
    for v in graph.getEdges() do degreeDist[graph.degree(v)] += 1;
    return degreeDist;
  }

  /*
    Obtain the component size distribution of vertices as a histogram.

    :arg graph: Hypergraph or graph.
    :arg s: Minimum s-connectivity.
  */
  proc vertexComponentSizeDistribution(graph, s = 1) {
    var components = getVertexComponents(graph, s);
    var vComponentSizes = [vc in components] vc.size();
    var largestComponent = max reduce vComponentSizes;
    var componentSizes : [1..largestComponent] int;
    for vcSize in vComponentSizes do componentSizes[vcSize] += 1;
    delete components;
    return componentSizes;
  }
  
  /*
    Obtain the component size distribution of edges as a histogram.

    :arg graph: Hypergraph or graph.
    :arg s: Minimum s-connectivity.
  */
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
}
