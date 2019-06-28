/*
  Compilation of common metrics to be performed on hypergraphs or graphs.
*/
module Metrics {
  use WorkQueue;
  use Vectors;
  use Utilities;
  use Traversal;

   /*
    Assigns vertices to components and assigns them component ids. Returns an array
    that is mapped over the same domain as the hypergraph or graph.

    :arg graph: Hypergraph or graph.
    :arg s: Minimum s-connectivity.
  */
  proc getVertexComponentMappings(graph, s = 1) {
    var components : [graph.verticesDomain] int;
    var numComponents : int;
    var componentId = 1; // Begin at 1 so 0 becomes 'not visited' sentinel value
    var workQueue = new WorkQueue(int, 1024 * 1024);
    var terminationDetector = new TerminationDetector();

    // Iterate over edges serially to avoid A) redundant work, B) large space needed for parallel
    // BFS, and C) bound the number of work we perform (as part of eliminating redundant work)
    for v in graph.verticesDomain {
      // If we have visited this vertex or if it has a degree less than 's', skip it.
      if components[v] != 0 || graph.degree(graph.toVertex(v)) < s then continue;
      const cId = componentId;
      componentId += 1;
      components[v] = cId;

      forall neighbor in graph.walk(graph.toVertex(v), s) {
        terminationDetector.started(1);
        workQueue.addWork(neighbor.id, graph.getLocale(neighbor));
      }

      forall vIdx in doWorkLoop(workQueue, terminationDetector) {
        // If we have not yet visited this vertex
        if components[vIdx] == 0 {
          components[vIdx] = cId;
          for neighbor in graph.walk(graph.toEdge(vIdx), s) {
            terminationDetector.started(1);
            workQueue.addWork(neighbor.id, graph.getLocale(neighbor));
          }
        }
        terminationDetector.finished(1);
      }
    }
    
    return components;
  }

  
  /*
    Assigns hyperedges to components and assigns them component ids. Returns an array
    that is mapped over the same domain as the hypergraph or graph. Component ids are
    
    :arg graph: Hypergraph or graph.
    :arg s: Minimum s-connectivity.
  */
  proc getEdgeComponentMappings(graph, s = 1) {
    var components : [graph.edgesDomain] int;
    var componentId = 1; // Begin at 1 so 0 becomes 'not visited' sentinel value
    var workQueue = new WorkQueue(int, 1024 * 1024);
    var terminationDetector = new TerminationDetector();

    // Iterate over edges serially to avoid A) redundant work, B) large space needed for parallel
    // BFS, and C) bound the number of work we perform (as part of eliminating redundant work)
    for e in graph.edgesDomain {
      // If we have visited this edge or if it has a degree less than 's', skip it.
      if components[e] != 0 || graph.degree(graph.toEdge(e)) < s then continue;
      const cId = componentId;
      componentId += 1;
      components[e] = cId;
      forall neighbor in graph.walk(graph.toEdge(e), s) {
        terminationDetector.started(1);
        workQueue.addWork(neighbor.id, graph.getLocale(neighbor));
      }

      
      forall eIdx in doWorkLoop(workQueue, terminationDetector) {
        if components[eIdx] == 0 {
          components[eIdx] = cId;
          for neighbor in graph.walk(graph.toEdge(eIdx), s) {
            terminationDetector.started(1);
            workQueue.addWork(neighbor.id, graph.getLocale(neighbor));
          }
        }
        terminationDetector.finished(1);
      }
    }
    
    return components;
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
    forall size in componentSizes with (+ reduce componentSizeDistribution) do componentSizeDistribution[size] += 1;
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
}
