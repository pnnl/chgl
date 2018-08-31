module Generation {

  use IO;
  use Random;
  use BlockDist;
  use CyclicDist;
  use Utilities;
  use AdjListHyperGraph;
  use BlockDist;
  use Math;
  use Sort;
  use Search;

  param GenerationSeedOffset = 0xDEADBEEF;
  config const GenerationUseAggregation = true;
  
  // Work for each task on each locale...
  record WorkInfo {
    // Seed to use for random number generator
    var rngSeed : int;
    // Offset in seed to calculate random number generator for
    var rngOffset : int;
    // Number of operations for locale
    var numOperations : int;
  }

  // Calculates work for each locale; does it in such a way that
  // we the random number generators can share the same seed safely.
  inline proc calculateWork(numInclusions, targetLoc = Locales) {
    // Generate seed...
    var seedGenerator = makeRandomStream(int);
    var seed = seedGenerator.getNext();
    seedGenerator;

    
    var workInfo : [0..#numLocales, 1..here.maxTaskPar] WorkInfo;
    var offset = 0;

    // Calculate and setup work information for each task on each locale
    for loc in targetLoc {
      const numOperations = numInclusions / numLocales + (if loc == here then numInclusions % numLocales else 0);
      for tid in 1..here.maxTaskPar {
        const numTaskOperations = numOperations / here.maxTaskPar + (if tid == 1 then numOperations % here.maxTaskPar else 0);
        workInfo[loc.id, tid] = new WorkInfo(
          rngSeed=seed,
          numOperations = numTaskOperations,
          rngOffset = offset
        );
        // We need to increment counter for each task twice per iteration
        // Once for the vertex, another for the edge... offset is shared
        // by both degreeRNG and nodeRNG. 
        offset += numTaskOperations * 2;
      }
    }

    return workInfo;
  }

  //Pending: Take seed as input
  //Returns index of the desired item
  inline proc weightedRandomSample(items, probabilities, randValue){
    assert(randValue >= 0 && randValue <= 1, "Random Value ", randValue, " is not between 0 and 1");
    var l = probabilities.domain.low;
    var r = probabilities.domain.high;
    while l < r {
      var m = floor((l + r) / 2) : int;
      if probabilities[m] < randValue {
        l = m + 1;
      } else {
        r = m;
      }
    }
    return l - (probabilities.domain.low - items.low);
  }
  
  proc distributedHistogram(probTable, numRandoms, targetLocales) {
    assert(probTable.domain.stride == 1, "Cannot perform histogram on strided arrays yet");
    var indicesSpace = {1..#numRandoms};
    var indicesDom = indicesSpace dmapped Block(boundingBox = indicesSpace, targetLocales = targetLocales);
    var indices : [indicesDom] int;
    var rngArr : [indicesDom] real;
    var newProbTableSpace = {1..#probTable.size + 1};
    var newProbTableDom = newProbTableSpace dmapped Cyclic(startIdx=1, targetLocales = targetLocales);
    var newProbTable : [newProbTableSpace] probTable.eltType;
    newProbTable[2..] = probTable;
    fillRandom(rngArr);
    const lo = newProbTable.domain.low;
    const hi = newProbTable.domain.high;
    const size = newProbTable.size;

    // probabilities is binrange, rngArr is X
    forall (rng, ix) in zip(rngArr, indices) {
      // Handle space cases...
      if rng == 0 {
        ix = 0;
      } else if rng == 1 {
        ix = size - 1;
      } else {
        var offset = 1;
        // Find a probability less than or equal to rng in log(n) time
        while (offset <= size && rng > newProbTable[offset]) {
          offset *= 2;
        }

        // Find the first probability less than or equal to rng
        offset = min(offset, size);
        while offset != 0 && rng <= newProbTable[offset - 1] {
          offset -= 1;
        }

        ix = offset - 2;
        assert(ix >= 0);
      }
    }

    return indices;
  }
  
  proc histogram(probabilities, numRandoms) {
    var indices : [1..#numRandoms] int;
    var rngArr : [1..#numRandoms] real;
    var newProbabilities : [1..1] real;
    if numRandoms == 0 then return indices;
    newProbabilities.push_back(probabilities);
    fillRandom(rngArr);
    const lo = newProbabilities.domain.low;
    const hi = newProbabilities.domain.high;
    const size = newProbabilities.size;

    // probabilities is binrange, rngArr is X
    forall (rng, ix) in zip(rngArr, indices) {
      // Handle space cases...
      if rng == 0 {
        ix = 0;
      } else if rng == 1 {
        ix = size - 1;
      } else {
        var offset = 1;
        // Find a probability less than or equal to rng in log(n) time
        while (offset <= size && rng > newProbabilities[offset]) {
          offset *= 2;
        }

        // Find the first probability less than or equal to rng
        offset = min(offset, size);
        while offset != 0 && rng < newProbabilities[offset - 1] {
          offset -= 1;
        }

        ix = offset - 2;
        assert(ix >= 0);
      }
    }
    
    return indices;
  }

  proc generateErdosRenyiSMP(graph, probability, vertexDomain, edgeDomain, couponCollector = true) {
    // Rounds a real into an int
    proc _round(x : real) : int {
      return round(x) : int;
    }
    const numVertices = vertexDomain.size;
    const numEdges = edgeDomain.size;
    var newP = if couponCollector then log(1/(1-probability)) else probability;
    var inclusionsToAdd = _round(numVertices * numEdges * newP);
    // Perform work evenly across all tasks
    var _randStream = new owned RandomStream(int, GenerationSeedOffset + here.id * here.maxTaskPar);
    var randStream = new owned RandomStream(int, _randStream.getNext());
    forall 1..inclusionsToAdd {
      var vertex = randStream.getNext(vertexDomain.low, vertexDomain.high);
      var edge = randStream.getNext(edgeDomain.low, edgeDomain.high);
      graph.addInclusion(vertex, edge);
    }

    return graph;
  }
  
  proc generateErdosRenyi(graph, probability, verticesDomain = graph.verticesDomain, edgesDomain = graph.edgesDomain, couponCollector = true, targetLocales = Locales){
    const numVertices = verticesDomain.size;
    const numEdges = edgesDomain.size;
    const vertLow = verticesDomain.low;
    const vertHigh = verticesDomain.high;
    const vertSize = verticesDomain.size;
    const vertStride = verticesDomain.stride;
    const edgeLow = edgesDomain.low;
    const edgeHigh = edgesDomain.high;
    const edgeSize = edgesDomain.size;
    const edgeStride = edgesDomain.stride;
    var newP = if couponCollector then log(1/(1-probability)) else probability;
    var inclusionsToAdd = round(numVertices * numEdges * newP) : int; 
    var workInfo = calculateWork(inclusionsToAdd, targetLocales);
    
    sync coforall loc in targetLocales do on loc {
      coforall tid in 1..here.maxTaskPar {
        var work = workInfo[here.id, tid];
        var rng = new owned RandomStream(int, seed=work.rngSeed);
        if work.rngOffset != 0 then rng.skipToNth(work.rngOffset);
        for 1..work.numOperations {
          var vertex = rng.getNext(0, vertSize - 1) * vertStride + vertLow;
          var edge = rng.getNext(0, edgeSize - 1) * edgeStride + edgeLow;
          graph.addInclusion(vertex, edge);
        }
      }
    }
    
    return graph;
  }

  proc generateChungLuSMP(graph, verticesDomain, edgesDomain, desiredVertexDegrees, desiredEdgeDegrees, inclusionsToAdd) {
    const reducedVertex = + reduce desiredVertexDegrees : real;
    const reducedEdge = + reduce desiredEdgeDegrees : real;
    var vertexProbabilities = desiredVertexDegrees / reducedVertex;
    var edgeProbabilities = desiredEdgeDegrees/ reducedEdge;
    var vertexScan : [vertexProbabilities.domain] real = + scan vertexProbabilities;
    var edgeScan : [edgeProbabilities.domain] real = + scan edgeProbabilities;


    return generateChungLuPreScanSMP(graph, verticesDomain, edgesDomain, vertexScan, edgeScan, inclusionsToAdd);
  }

  proc generateChungLuPreScanSMP(graph, verticesDomain, edgesDomain, vertexScan, edgeScan, inclusionsToAdd){
    // Perform work evenly across all locales
    coforall tid in 0..#here.maxTaskPar {
      // Perform work evenly across all tasks
      var perTaskInclusions = inclusionsToAdd / here.maxTaskPar + (if tid == 0 then inclusionsToAdd % here.maxTaskPar else 0);
      var _randStream = new owned RandomStream(int, GenerationSeedOffset + here.id * here.maxTaskPar + tid);
      var randStream = new owned RandomStream(real, _randStream.getNext());
      for 1..perTaskInclusions {
        var vertex = weightedRandomSample(verticesDomain, vertexScan, randStream.getNext());
        var edge = weightedRandomSample(edgesDomain, edgeScan, randStream.getNext());
        graph.addInclusion(vertex, edge);
      }
    }

    return graph;
  }
  
  // Compute Table degrees to vertices...
  record DynamicArray {
    var dom = {0..-1};
    var arr : [dom] int;
    
    proc init() {

    }
    
    proc init(other) {
      this.dom = other.dom;
      this.arr = other.arr;
    }
    
    inline proc this(idx : integral) const ref { return arr[idx]; }
  }
  
  /*
    Generates a graph from the desired vertex and edge degree sequence. 

    :arg graph: Mutable graph to generate.
    :arg vDegSeq: Vertex degree sequence. Must be sorted.
    :arg eDegSeq: HyperEdge degree sequence. Must be sorted.
    :arg inclusionsToAdd: Number of edges to create between vertices and hyperedges.
    :arg verticesDomain: Subset of vertices to generate edges between. Defaults to the entire set of vertices.
    :arg edgesDomain: Subset of hyperedges to generate edges between. Defaults to the entire set of hyperedges.
    :arg targetLoc: Locales to perform computation over. Defaults to Locales, which includes all locales.
  */
  proc generateChungLu(
      graph, vDegSeq : [?vDegSeqDom] int, eDegSeq : [?eDegSeqDom] int, inclusionsToAdd : int(64),
      verticesDomain = graph.verticesDomain, edgesDomain = graph.edgesDomain, targetLoc = Locales) {
    // Check if empty...
    if inclusionsToAdd == 0 || graph.verticesDomain.size == 0 || graph.edgesDomain.size == 0 then return graph;
   
    // Create a table of random vertices
    var vDegTableDom = {0..-1};
    var eDegTableDom = {0..-1};
    var vDegTable : [vDegTableDom] real;
    var eDegTable : [eDegTableDom] real;
    var vMaxDeg = max reduce vDegSeq; 
    var eMaxDeg = max reduce eDegSeq;
   
    cobegin with (ref vMaxDeg, ref eMaxDeg, ref vDegTableDom, ref eDegTableDom) {
      {
        vMaxDeg = max reduce vDegSeq;
        vDegTableDom = {1..vMaxDeg};
        forall deg in vDegSeq do if deg > 0 then vDegTable[deg] = deg : real;
        vDegTable /= + reduce vDegTable;
        vDegTable = + scan vDegTable;
      }
      {
        eMaxDeg = max reduce eDegSeq;
        eDegTableDom = {1..eMaxDeg};
        var prevDeg = 0;
        forall deg in eDegSeq do if deg > 0 then eDegTable[deg] = deg : real;
        eDegTable /= + reduce eDegTable;
        eDegTable = + scan eDegTable;
      }
    }
    
    var vTableDom = {0..-1} dmapped Cyclic(startIdx=0);
    var eTableDom = {0..-1} dmapped Cyclic(startIdx=0);
    var vTable : [vTableDom] int;
    var eTable : [eTableDom] int;
    // Holds beginning of offset into each distributed array table; (offset, size) pairs
    var vTableMeta : [1..vMaxDeg] (int, int);
    var eTableMeta : [1..eMaxDeg] (int, int);
    var aggregator = new Aggregator((int, int));
    
    // Construct vTable
    {
      var vDegSize : [1..vMaxDeg] chpl__processorAtomicType(int);
      forall (vDeg, v) in zip(vDegSeq, vDegSeqDom) {
        if vDeg != 0 then vDegSize[vDeg].add(1);
      }

      var currOffset = 0;
      for (size, (offset, sz)) in zip(vDegSize, vTableMeta) {
        sz = size.peek();
        offset = currOffset;
        currOffset += sz;
      }

      vTableDom = {0..#currOffset};
      
      // Fill in distributed edge table
      // Aggregates (idx, vertex) pairs; will turn into vTable[idx] = vertex
      sync forall (vertex, deg) in zip(vDegSeq.domain, vDegSeq) {
        if deg >= 1 {
          var idx = vDegSize[deg].fetchSub(1) - 1;
          if idx < 0 then halt("Bad degree index: ", idx, " for degree ", deg);
          
          // Apply offset of degree to index
          idx += vTableMeta[deg][1];
          const loc = vTable.domain.dist.idxToLocale(idx);
          var buf = aggregator.aggregate((idx, vertex), loc);
          if buf != nil then begin on loc { 
            [(i,v) in buf] vTable[i] = v;
            buf.done();
          }
        }
      }
      forall (buf, loc) in aggregator.flushGlobal() {
        on loc do [(i,v) in buf] vTable[i] = v;
        buf.done();
      }
    }

    //Construct eTable
    {
      // Obtain size of distributed edges domain
      var eDegSize : [1..eMaxDeg] chpl__processorAtomicType(int);
      forall (eDeg, e) in zip(eDegSeq, eDegSeqDom) {
        if eDeg != 0 then eDegSize[eDeg].add(1);
      }

      var currOffset = 0;
      for (size, (offset, sz)) in zip(eDegSize, eTableMeta) {
        sz = size.peek();
        offset = currOffset;
        currOffset += sz;
      }

      eTableDom = {0..#currOffset};

      // Fill in distributed edge table
      // Aggregates (idx, edge) pairs; will turn into eTable[idx] = edge
      sync forall (edge, deg) in zip(eDegSeq.domain, eDegSeq) {
        if deg >= 1 {
          var idx = eDegSize[deg].fetchSub(1) - 1;
          if idx < 0 then halt("Bad degree index: ", idx, " for degree ", deg);
          
          // Apply offset of degree to index
          idx += eTableMeta[deg][1];
          const loc = eTable.domain.dist.idxToLocale(idx);
          var buf = aggregator.aggregate((idx, edge), loc);
          if buf != nil then begin on loc { 
            [(i,e) in buf] eTable[i] = e;
            buf.done();
          }
        }
      }
      forall (buf, loc) in aggregator.flushGlobal() {
        on loc do [(i,e) in buf] eTable[i] = e;
        buf.done();
      }
    }
    aggregator.destroy();

    var workInfo = calculateWork(inclusionsToAdd, targetLoc);

    // Perform work evenly across all locales
    coforall loc in targetLoc do on loc {
      const _vDegDom = vDegTable.domain;
      const _eDegDom = eDegTable.domain;
      var _vDegTable : [_vDegDom] real = vDegTable;
      var _eDegTable : [_eDegDom] real = eDegTable;
      
      const _vTableDom = vTableMeta.domain;
      const _eTableDom = eTableMeta.domain;
      var _vTableMeta : [_vTableDom] (int, int) = vTableMeta;
      var _eTableMeta : [_eTableDom] (int, int) = eTableMeta;
      var _workInfo = workInfo;
      
      sync coforall tid in 1..here.maxTaskPar {
        const work = _workInfo[here.id, tid];
        // Perform work evenly across all tasks
        var degreeRNG = new owned RandomStream(real, work.rngSeed);
        var nodeRNG = new owned RandomStream(int, work.rngSeed);
        if work.rngOffset != 0 { 
          degreeRNG.skipToNth(work.rngOffset);
          nodeRNG.skipToNth(work.rngOffset);
        }

        for 1..work.numOperations {
          const vDegIdx = weightedRandomSample({1..vMaxDeg}, _vDegTable, degreeRNG.getNext());  
          const eDegIdx = weightedRandomSample({1..eMaxDeg}, _eDegTable, degreeRNG.getNext());
          const (vDegOffset, vDegSize) = _vTableMeta[vDegIdx];
          const (eDegOffset, eDegSize) = _eTableMeta[eDegIdx];
          const vIdx = nodeRNG.getNext(vDegOffset, vDegOffset + vDegSize - 1);
          const eIdx = nodeRNG.getNext(eDegOffset, eDegOffset + eDegSize - 1);
          const vertex = vTable[vIdx];
          const edge = eTable[eIdx];
          graph.addInclusionBuffered(vertex, edge);
        }
      }
      graph.flushBuffers();
    }
    return graph;
  }
  
  proc generateChungLuAdjusted(graph, num_vertices, num_edges, desired_vertex_degrees, desired_edge_degrees){
    var inclusions_to_add =  + reduce desired_vertex_degrees:int;
    return generateChungLu(graph, num_vertices, num_edges, desired_vertex_degrees, desired_edge_degrees, inclusions_to_add);
  }

  // Computes the triple (nV, nE, rho) which are used to determine affinity blocks
  proc computeAffinityBlocks(dV, dE, mV, mE){
      var (nV, nE, rho) : 3 * real;

      //determine the nV, nE, rho
      if (mV / mE >= 1) {
        nV = dE;
        nE = (mV / mE) * dV;
        rho = (((dV - 1) * (mE ** 2.0)) / (mV * dV - mE)) ** (1 / 4.0);
      } else {
        nE = dV;
        nV = (mE / mV) * dE;
        rho = (((dE - 1) * (mV ** 2.0))/(mE * dE - mV)) ** (1 / 4.0);
      }

      assert(!isnan(rho), (dV, dE, mV, mE), "->", (nV, nE, rho));

      return (_round(nV), _round(nE), rho);
  }

  // Rounds a real into an int
  proc _round(x : real) : int {
      return round(x) : int;
  }

  /*
    Block Two-Level Erdos Renyi
  */
  proc generateBTER(
      vd : [?vdDom], /* Vertex Degrees */
      ed : [?edDom], /* Edge Degrees */
      vmc : [?vmcDom], /* Vertex Metamorphosis Coefficient */
      emc : [?emcDom], /* Edge Metamorphosis Coefficient */
      targetLocales = Locales
      ) {

    // Obtains the minimum value that exceeds one
    proc minimalGreaterThanOne(arr) {
      for (a, idx) in zip(arr, arr.dom) do if a > 1 then return idx;
      halt("No member found that is greater than 1...");
    }

    // Check if data begins at index 0...
    assert(vdDom.low == 0 && edDom.low == 0 && vmcDom.low == 0 && emcDom.low == 0);
    cobegin {
      sort(vd);
      sort(ed);
    }

    var (nV, nE, rho) : 3 * real;
    var (idV, idE, numV, numE) = (
        minimalGreaterThanOne(vd),
        minimalGreaterThanOne(ed),
        vdDom.size,
        edDom.size
        );
    var graph = new AdjListHyperGraph(vdDom.size, edDom.size, new unmanaged Cyclic(startIdx=0:int(32)));

    var blockID = 1;
    var expectedDuplicates : int;
    graph.startAggregation();
    while (idV <= numV && idE <= numE){
      var (dV, dE) = (vd[idV], ed[idE]);
      var (mV, mE) = (vmc[dV - 1], emc[dE - 1]);
      (nV, nE, rho) = computeAffinityBlocks(dV, dE, mV, mE);
      var nV_int = nV:int;
      var nE_int = nE:int;
      blockID += 1;

      // Check to ensure that blocks are only applied when it fits
      // within the range of the number of vertices and edges provided.
      // This avoids processing a most likely "wrong" value of rho as
      // mentioned by Sinan.
      if (((idV + nV_int) <= numV) && ((idE + nE_int) <= numE)) {
        if nE_int < 0 || nV_int < 0 {
          writeln("idV = ", idV);
          writeln("idE = ", idE);
          writeln("numV = ", numV);
          writeln("numE = ", numE);
          writeln("nV = ", nV);
          writeln("nV : int = ", nV : int);
          writeln("nE = ", nE);
          writeln("nE : int = ", nE : int);
          writeln("rho = ", rho);
          writeln("dV = ", dV);
          writeln("dE = ", dE);
          writeln("mV = ", mV);
          writeln("mE = ", mE);
          writeln("blockID = ", blockID);
          halt("Bad idx");
        }
        const ref verticesDomain = graph.verticesDomain[idV..#nV_int];
        const ref edgesDomain = graph.edgesDomain[idE..#nE_int];
        expectedDuplicates += round((nV_int * nE_int * log(1/(1-rho))) - (nV_int * nE_int * rho)) : int;
        // Compute affinity blocks
        var rng = new owned RandomStream(int, parSafe=true);
        forall v in verticesDomain {
          for (e, p) in zip(edgesDomain, rng.iterate(edgesDomain)) {
            if p > rho then graph.addInclusion(v,e);
          }
        }

        idV += nV_int;
        idE += nE_int;
      } else {
        break;
      }
    }
    graph.stopAggregation();
    graph.removeDuplicates();
    
    forall (v, vDeg) in graph.forEachVertexDegree() {
      var oldDeg = vd[v.id];
      vd[v.id] = max(0, oldDeg - vDeg);
    }
    forall (e, eDeg) in graph.forEachEdgeDegree() {
      var oldDeg = ed[e.id];
      ed[e.id] = max(0, oldDeg - eDeg);
    }
    var nInclusions = _round(max(+ reduce vd, + reduce ed));
    generateChungLu(graph, vd, ed, nInclusions);
    return graph;
  }
}

