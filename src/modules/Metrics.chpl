use AdjListHyperGraph;
use Generation;
use FIFOChannel;
use WorkQueue;
use TerminationDetection;
use ReplicatedVar;

/* 
  Represents 's-walk' state. We manage the current hyperedge sequence
  as well as our current neighbor.
*/
record WalkState {
  type edgeType;
  type vertexType;
  
  // The current sequences of edges that we have s-walked to.
  var sequenceDom = {0..-1};
  var sequence : [sequenceDom] edgeType;
  
  // Our current neighbor and if we are checking them.
  // Since we need to find two-hop neighbors, we need
  // to do them on the respective locale as well.
  var neighbor : vertexType;
  var checkingNeighbor : bool;
  var checkingIntersection : bool;

  proc init(other) {
    this.edgeType = other.edgeType;
    this.vertexType = other.vertexType;
    this.sequenceDom = other.sequenceDom;
    this.complete();
    this.sequence = other.sequence;
    this.neighbor = other.neighbor;
    this.checkingNeighbor = other.checkingNeighbor;
  }

  proc init(type edgeType, type vertexType, size = -1) {
    this.edgeType = edgeType;
    this.vertexType = vertexType;
    this.sequenceDom = {0..#size};
  }

  inline proc append(edge : edgeType) {
    this.sequence.push_back(edge);
  }

  inline proc setNeighbor(vertex : vertexType) {
    this.neighbor = vertex;
    this.checkingNeighbor = true;
  }

  inline proc unsetNeighbor() {
    this.checkingNeighbor = false;
  }

  inline proc setIntersection() {
    this.checkingIntersection = true;
  }
  
  inline proc isCheckingNeighbor() return this.checkingNeighbor;
  inline proc getNeighbor() return this.currentNeighbor;
  inline proc isCheckingIntersection() return this.checkingIntersection;
  inline proc numSequences return this.sequenceDom.size;
  inline proc getTop() return this(this.numSequences - 1);

  inline proc hasProcessed(edge : edgeType) {
    for e in sequence do if e.id == edge.id then return true;
    return false;
  }

  inline proc this(idx : integral) ref {
    assert(idx >= 0 && idx < numSequences);
    return sequence[idx];
  }
}

iter walk(graph, s = 1, k = 2) {
  halt("Serial walk not implemented...");
}

// TODO: Profile iterator this nested...
iter walk(graph, s = 1, k = 2, param tag : iterKind) where tag == iterKind.standalone {
  type edgeType = graph._value.eDescType;
  type vertexType = graph._value.vDescType;
  var workQueue = new WorkQueue(WalkState(edgeType, vertexType)); 
  var keepAlive : [rcDomain] bool;
  var terminationDetector = new TerminationDetector();
  rcReplicate(keepAlive, true);
  
  // Insert initial states...
  forall e in graph.getEdges() with (in graph, in workQueue, in terminationDetector) {
    // Iterate over neighbors
    forall v in graph.getNeighbors(e) with (in graph, in workQueue, in terminationDetector, in e) {
      var state = new WalkState(edgeType, vertexType, 1);
      state[0] = e;
      state.setNeighbor(v);
      terminationDetector.started();
      workQueue.addWork(state, graph.getLocale(v));
    }
  }

  // With the queue populated, we can begin our work loop...
  // Spawn a new task to handle alerting each locale that they can stop...
  begin {
    terminationDetector.wait(minBackoff = 1, maxBackOff = 100);
    rcReplicate(keepAlive, false);
  }
  
  // Begin work queue loops; a task on each locale, and then spawn up to the
  // maxmimum parallelism on each respective locales. Each of the tasks will
  // wait on the replicated 'keepAlive' flag. Each time a state is created
  // and before it is added to the workQueue, the termination detector will
  // increment the number of tasks started, and whenever a state is finished
  // it will increment the number of tasks finished...
  coforall loc in Locales with (in graph, in workQueue, in terminationDetector) do on loc {
    coforall tid in 1..here.maxTaskPar {
      var (hasState, state) : (bool, WalkState(edgeType, vertexType));
      while rcLocal(keepAlive) {
        (hasState, state) = workQueue.getWork();
        if !hasState {
          chpl_task_yield();
          continue;
        }

        // Process based on state...
        if state.isCheckingNeighbor() {
          var v = state.getNeighbor();
          state.unsetNeighbor();
          for e in graph.getNeighbors(v) {
            if state.hasProcess(e) then continue;
            var newState = state;
            newState.append(e);
            terminationDetector.start();
            workQueue.addWork(newState, graph.getLocales(e));
          }
          terminationDetector.finish();
        } else if state.isCheckingIntersection() {
          var (e1, e2) = (state[state.numSequences - 2], state[state.numSequences - 1]);
          // Check if it is not s-intersecting... if so, check to see if we have reached
          // a length of at least 'k' to determine if we should yield current sequence...
          if graph.intersection(e1, e2).size < s {
            if state.numSequences - 1 >= k {
              yield state.sequences[0..#(state.numSequences - 1)];
            }
            terminationDetector.finish();
            continue;
          }  
          
          // Continue searching neighbors...
          terminationDetector.start(graph.numNeighbors(e2));
          for v in graph.getNeighbors(e2) {
            var newState = state;
            newState.checkNeighbor(v);
            workQueue.addWork(newState, graph.getLocales(v));
          }
          terminationDetector.finish();
        } else {
          // If we are not checking intersection or a specific neighbor, we are in charge
          // setting up state for checking all other neighbors
          var e = state.getTop();
          terminationDetector.start(graph.numNeighbors(e));
          for v in graph.getNeighbors(e) {
            // TODO: Profile whether this simulates a 'move' constructor...
            var newState = state;
            newState.checkNeighbor(v);
            workQueue.addWork(newState, graph.getLocales(v));
          }
          terminationDetector.finish();
        }
      }
    }
  }
}

proc main() {
  var graph = new AdjListHyperGraph(1024, 1024);
  generateErdosRenyiSMP(graph, 0.25);
  graph.removeDuplicates();
  forall w in walk(graph) do writeln(here, ": ", w);
}
