/*
  Compilation of common metrics to be performed on hypergraphs or graphs.
*/
prototype module Metrics {
  use CHGL;
  use Vectors;
  use Utilities;
  use Traversal;
  use Sort;
  use DynamicAggregationBuffer;

  // Coalescing of s-connected components. When given the
  // array of (idx, cid) pairs, we want to eliminate the
  // greater cids directed at the same idx. We also eliminate
  // redundant cids.
  record ComponentCoalescer {
    proc this(arr : [?D] (int, int)) {
      var indicesDom : domain(int); // idx
      var indices : [indicesDom] int;  // cid

      for (idx, cid) in arr {
        if indicesDom.contains(idx) {
          const _cid = indices[idx];
          if _cid > cid {
            indices[idx] = cid;
          }
        } else {
          indicesDom += idx;
          indices[idx] = cid;
        }
      }

      var arrIdx = D.low;
      for (idx, cid) in zip(indicesDom, indices) {
        arr[arrIdx] = (idx, cid);
        arrIdx += 1;
      }

      if arrIdx < D.high {
        arr[arrIdx..] = (-1, -1);
      }
    } 
  }

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
      var sequence : [0..-1] graph._value.vDescType;
      component += 1;
      components[v.id] = component;
      sequence.push_back(v);
      for vv in vertexBFS(graph, v, s) {
        if boundsChecking then assert(components[vv.id] == 0, "Already visited a vertex during BFS...", vv);
        components[vv.id] = component;
        sequence.push_back(vv);
      }
      yield sequence;
    }
  }

  /*
     Iterate over all edges in graph and count the number of s-connected components.
     A s-connected component is a group of vertices that can be s-walked to. A edge
     e can s-walk to a edge e' if the intersection of both e and e' is at least s.

     .. note::

       This is significantly slower than `getEdgeComponentMappings`
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
      var sequence : [0..-1] graph._value.eDescType;
      component += 1;
      components[e.id] = component;
      sequence.push_back(e);
      for ee in edgeBFS(graph, e, s) {
        if boundsChecking then assert(components[ee.id] == 0, "Already visited an edge during BFS...", ee);
        components[ee.id] = component;
        sequence.push_back(ee);
      }
      yield sequence;
    }
  }


   /*
    Assigns vertices to components and assigns them component ids. Returns an array
    that is mapped over the same domain as the hypergraph or graph.

    :arg graph: Hypergraph or graph.
    :arg s: Minimum s-connectivity.
  */
  proc getVertexComponentMappings(graph, s = 1) {
    // var dom = graph.verticesDomain;
    //var components : [dom] atomic int;
    var components : [graph.verticesDomain] atomic int;
    var componentId : atomic int;
    var workQueue = new WorkQueue((int,int), 8 * 1024, new ComponentCoalescer());
    var terminationDetector = new TerminationDetector();

    // Begin at 1 so 0 becomes 'not visited' sentinel value
    componentId.write(1);
    
    // Add all edges with a degree of at least 's' to the work queue
    // so we can perform a breadth-first search.
    for v in graph.verticesDomain {
      // writeln("trying to add vertex: " + v + " to the work queue");
      if graph.degree(graph.toVertex(v)) >= s {
	// writeln("adding vertex: " + v + " to the work queue");
        terminationDetector.started(1);
        workQueue.addWork((v, 0));
    /*   } */
    /* } */
    /* writeln("Added all vertices with s " + s); */
    forall (vIdx, cid) in doWorkLoop(workQueue, terminationDetector) {
      if vIdx != -1 && cid != -1 && graph.degree(graph.toVertex(vIdx)) >= s {
        const cId = if cid == 0 then componentId.fetchAdd(1) else cid;
        // If the component id is not set for this edge, or if the component
        // id has a larger value, we can try to 'claim' this edge, and if successful
        // try to claim its neighbors, and so on and so forth. If the component
        // id has a smaller or equal value, we do nothing.
        var shouldAddNeighbors = false;
        while true do local {
          var currId = components[vIdx].read();
          if (currId == 0 || currId > cId) {
            // Claimed...
            if components[vIdx].compareExchange(currId, cId) {
              shouldAddNeighbors = true;
              break;
            }
          } else if CHPL_NETWORK_ATOMICS != "none" && currId == cId {
            shouldAddNeighbors = true;
            break;
          } else {
            // Edge is already claimed by an equal or lower component id. Do nothing.
            break;
          }
        }
        if shouldAddNeighbors {
	  forall neighbor in graph.walk(graph.toVertex(vIdx), s, isImmutable=true) {
            if CHPL_NETWORK_ATOMICS != "none" {
              // Claim vertex remotely
              while true {
                var neighborComponentId = components[neighbor.id].read();
                if neighborComponentId == 0 || neighborComponentId > cId {
                  if components[neighbor.id].compareExchange(neighborComponentId, cId) {
                    terminationDetector.started(1);
                    workQueue.addWork((neighbor.id, cId), graph.getLocale(neighbor));
                    break;
                  }
                } else {
                  break;
                }
              }
            } else {
              terminationDetector.started(1);
              workQueue.addWork((neighbor.id, cId), graph.getLocale(neighbor));
            }
          }
        }
      }
      terminationDetector.finished(1);
    }
      }
    }
    
    terminationDetector.destroy();
    workQueue.destroy();
    return components.read();
  }

  /*
    Assigns hyperedges to components and assigns them component ids. Returns an array
    that is mapped over the same domain as the hypergraph or graph. Component ids are
    
    :arg graph: Hypergraph or graph.
    :arg s: Minimum s-connectivity.
  */
  proc getEdgeComponentMappings(graph, s = 1) {
    var components : [graph.edgesDomain] atomic int;
    var componentId : atomic int;
    var workQueue = new WorkQueue((int,int), 8 * 1024, new ComponentCoalescer());
    var terminationDetector = new TerminationDetector();

    // Begin at 1 so 0 becomes 'not visited' sentinel value
    componentId.write(1);
    
    // Add all edges with a degree of at least 's' to the work queue
    // so we can perform a breadth-first search.
    for e in graph.edgesDomain {
      if graph.degree(graph.toEdge(e)) >= s {
        terminationDetector.started(1);
        workQueue.addWork((e, 0));

    forall (eIdx, cid) in doWorkLoop(workQueue, terminationDetector) {
      if eIdx != -1 && cid != -1 && graph.degree(graph.toEdge(eIdx)) >= s {
        const cId = if cid == 0 then componentId.fetchAdd(1) else cid;

        // If the component id is not set for this edge, or if the component
        // id has a larger value, we can try to 'claim' this edge, and if successful
        // try to claim its neighbors, and so on and so forth. If the component
        // id has a smaller or equal value, we do nothing. 
        var shouldAddNeighbors = false;
        while true do local {
          var currId = components[eIdx].read();
          if currId == 0 || currId > cId {
            // Claimed...
            if components[eIdx].compareExchange(currId, cId) {
              shouldAddNeighbors = true;
              break;
            }
          } else if CHPL_NETWORK_ATOMICS != "none" && currId == cId {
            shouldAddNeighbors = true;
            break;
          } else {
            // Edge is already claimed by an equal or lower component id. Do nothing.
            break;
          }
        }
        if shouldAddNeighbors {
          forall neighbor in graph.walk(graph.toEdge(eIdx), s, isImmutable=true) {
            if CHPL_NETWORK_ATOMICS != "none" {
              // Claim vertex remotely
              while true {
                var neighborComponentId = components[neighbor.id].read();
                if neighborComponentId == 0 || neighborComponentId > cId {
                  if components[neighbor.id].compareExchange(neighborComponentId, cId) {
                    terminationDetector.started(1);
                    workQueue.addWork((neighbor.id, cId), graph.getLocale(neighbor));
                    break;
                  }
                } else {
                  break;
                }
              }
            } else {
              terminationDetector.started(1);
              workQueue.addWork((neighbor.id, cId), graph.getLocale(neighbor));
            }
          }
        }
      }
      terminationDetector.finished(1);
    }
      }
    }

    
    terminationDetector.destroy();
    workQueue.destroy();
    return components.read();
  }

  /*
    Obtain the degree distribution of vertices as a histogram.
    
    :arg graph: Hypergraph or graph.
  */
  proc vertexDegreeDistribution(graph) {
    var maxDeg = max reduce [v in graph.getVertices()] graph.degree(graph.toVertex(v));
    var degreeDist : [1..maxDeg] int;
    forall v in graph.getVertices() with (+ reduce degreeDist) do degreeDist[graph.degree(v)] += 1;
    return degreeDist;
  }

  /*
    Obtain the degree distribution of edges as a histogram.
    
    :arg graph: Hypergraph or graph.
  */
  proc edgeDegreeDistribution(graph) {
    var maxDeg = max reduce [e in graph.getEdges()] graph.degree(graph.toEdge(e));
    var degreeDist : [1..maxDeg] int;
    forall e in graph.getEdges() with (+ reduce degreeDist) do degreeDist[graph.degree(e)] += 1;
    return degreeDist;
  }

  proc componentSizeDistribution(componentMappings : [?D] int) {
    // Obtain the largest component id.
    var maxComponentId = max reduce componentMappings;
    var componentSizes : [1..maxComponentId] int;
    forall cid in componentMappings with (+ reduce componentSizes) do if cid != 0 then componentSizes[cid] += 1;
    var maxComponentSize = max reduce componentSizes;
    var componentSizeDistribution : [1..maxComponentSize] int;
    forall size in componentSizes with (+ reduce componentSizeDistribution) do if size != 0 then componentSizeDistribution[size] += 1;
    return componentSizeDistribution;
  }

  /*
    Obtain the component size distribution of vertices as a histogram.

    :arg graph: Hypergraph or graph.
    :arg s: Minimum s-connectivity.
  */
  proc vertexComponentSizeDistribution(graph, s = 1) {
    return componentSizeDistribution(getVertexComponentMappings(graph, s));   
  }
  
  /*
    Obtain the component size distribution of edges as a histogram.

    :arg graph: Hypergraph or graph.
    :arg s: Minimum s-connectivity.
  */
  proc edgeComponentSizeDistribution(graph, s = 1) {
    return componentSizeDistribution(getEdgeComponentMappings(graph, s));
  }

  proc sDistance(graph, source, target, s) {
    const Space = graph.edgesDomain;
    const D: domain(1) dmapped Block(boundingBox=Space) = Space;
    var distance: [D] real = INFINITY;
    var current_distance  = 0;

    distance[graph.toEdge(source).id] = current_distance;
    for ee in edgeBFS(graph, graph.toEdge(source), s) {
      current_distance = current_distance + 1;
      var old_distance = distance[graph.toEdge(ee).id];
      if (isinf(old_distance) || old_distance > current_distance) {
	distance[graph.toEdge(ee).id] = current_distance;
      }
    }
    writeln(distance);
    return distance[graph.toEdge(target).id];
  }
}

