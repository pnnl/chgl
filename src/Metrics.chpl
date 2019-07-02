/*
  Compilation of common metrics to be performed on hypergraphs or graphs.
*/
module Metrics {
  use WorkQueue;
  use Vectors;
  use Utilities;
  use Traversal;
  use DynamicAggregationBuffer;

  record EdgeSorter {
    var graph;
    proc init(graph) {
      this.graph = graph;
    }

    proc key(e) { return graph.degree(graph.toEdge(e)); }
  }
  
  record VertexSorter {
    var graph;
    proc init(graph) {
      this.graph = graph;
    }

    proc key(e) { return graph.degree(graph.toVertex(e)); }
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
    var components : [graph.verticesDomain] atomic int;
    var numComponents : int;
    var componentId = 1; // Begin at 1 so 0 becomes 'not visited' sentinel value
    var workQueue = new WorkQueue(int, 1024 * 1024);
    var terminationDetector = new TerminationDetector();
    
    // Iterate over edges serially to avoid A) redundant work, B) large space needed for parallel
    // BFS, and C) bound the number of work we perform (as part of eliminating redundant work)
    for v in graph.verticesDomain do on graph.getLocale(graph.toVertex(v)) {
      // If we have visited this vertex or if it has a degree less than 's', skip it.
      if components[v].read() != 0 || graph.degree(graph.toVertex(v)) < s {}
      else {
        const cId = componentId;
        componentId += 1;
        components[v].write(cId);

        forall neighbor in graph.walk(graph.toVertex(v), s) {
          terminationDetector.started(1);
          const loc = graph.getLocale(neighbor);
          workQueue.addWork(neighbor.id, loc);
        }

        forall vIdx in doWorkLoop(workQueue, terminationDetector) {
          // If we have not yet visited this vertex
          if components[vIdx].compareExchange(0, cId) {
            for neighbor in graph.walk(graph.toVertex(vIdx), s) {
              terminationDetector.started(1);
              const loc =  graph.getLocale(neighbor);
              workQueue.addWork(neighbor.id,loc);
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
    var componentId = 1; // Begin at 1 so 0 becomes 'not visited' sentinel value
    var workQueue = new WorkQueue(int, 1024 * 1024);
    var terminationDetector = new TerminationDetector();
    
    // Iterate over edges serially to avoid A) redundant work, B) large space needed for parallel
    // BFS, and C) bound the number of work we perform (as part of eliminating redundant work)
    for e in graph.edgesDomain do on graph.getLocale(graph.toEdge(e)) {
      // If we have visited this edge or if it has a degree less than 's', skip it.
      if components[e].read() != 0 || graph.degree(graph.toEdge(e)) < s {}
      else {
        const cId = componentId;
        componentId += 1;
        components[e].write(cId);
        forall neighbor in graph.walk(graph.toEdge(e), s) {
          terminationDetector.started(1);
          const loc = graph.getLocale(neighbor);
          workQueue.addWork(neighbor.id, loc);
        }


        forall eIdx in doWorkLoop(workQueue, terminationDetector) {
          if components[eIdx].compareExchange(0, cId) {
            for neighbor in graph.walk(graph.toEdge(eIdx), s) {
              terminationDetector.started(1);
              const loc = graph.getLocale(neighbor);
              workQueue.addWork(neighbor.id, loc);
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
