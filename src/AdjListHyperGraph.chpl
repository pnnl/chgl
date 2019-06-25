/*  
  A global-view, distributed, and parallel dual hypergraph.
  _________________________________________________________

  The hypergraph maintains two distributed arrays, one for vertices and one for hyperedges. Both
  arrays contain objects that serve and act as adjacency, or incidence lists. For vertices, they
  contain the hyperedges they are contained in, and for hyperedges, they contain the vertices that
  are contained within itself. The graph is 'global-view' in that it allows the user to access the
  graph without regard for locality, while also being optimized locality. For example, all accesses
  to the hypergraph, whether it be in explicit `on` statements or 'coforall'/`forall` distributed
  and parallel loops, all accesses to the graph are forwarded to a local instance.

  .. note::

    Documentation is currently a Work In Progress!

  Usage
  _____

  
  There are a few ways to create a :record:`AdjListHyperGraph`

  .. code-block:: chapel
  
    // Creates a shared-memory hypergraph
    var graph = new AdjListHyperGraph(numVertices, numEdges);
    // Creates a distributed-memory hypergraph
    var graph = new AdjListHyperGraph(numVertices, numEdges, new Cyclic(startIdx=0));
    var graph = new AdjListHyperGraph(numVertices, numEdges, 
      new Block(boundingBox={0..#numVertices}, new Block(boundingBox={0..#numEdges})
    );
    // Creates a shared-memory hypergraph from Property Map
    var graph = new AdjListHyperGraph(propertyMap);
    // Creates a distributed hypergraph from Property Map
    var graph = new AdjListHyperGraph(propertyMap, new Cyclic(startIdx=0));
 
*/
module AdjListHyperGraph {
  use IO;
  use CyclicDist;
  use LinkedLists;
  use Sort;
  use Search;
  use AggregationBuffer;
  use Vectors;
  use PropertyMaps;
  use EquivalenceClasses;
  
  pragma "no doc"
  // Best-case approach to redistribution of properties to nodes in the hypergraph; this
  // will try to ensure as many properties remain local to node it belongs to as possible.
  proc =(ref A : [?D] ?T, M : PropertyMap(?propType)) {
    // For each locale, handle assigning local properties to local portions of the array.
    // The number of properties and last index read of the array represent "leftover" 
    // properties and are recordered below.
    var leftoverProperties : [0..-1] propType;
    var leftoverIndices : [0..-1] int;
    var propLock$ : sync bool;
    coforall loc in Locales with (ref propLock$, ref leftoverIndices, ref leftoverProperties) do on loc {
      // Counters representing the current indices of properties.
      var propIdx : int;
      var arrayIdx : int;
      var localIndices : [0..#A.domain.localSubdomain().size] int = A.domain.localSubdomain();
      var localProperties = M.keys.these();
      ref iterIndices = localIndices[0..#min(localIndices.size, localProperties.size)];
      ref iterProperties = localProperties[localProperties.domain.low..#min(localIndices.size, localProperties.size)];
      forall (idx, prop) in zip(iterIndices, iterProperties) {
        M.setProperty(prop, idx);
        A[idx].property = prop;
      }
    
      if localIndices.size != localProperties.size {
        on propLock$ {
          propLock$ = true;
          leftoverIndices.push_back(localIndices[min(localIndices.size, localProperties.size)-1..localIndices.size-1]);
          leftoverProperties.push_back(localProperties[min(localIndices.size, localProperties.size)-1..localProperties.size-1]);
          propLock$;
        }
      }
    }
    
    assert(leftoverProperties.size == leftoverIndices.size, "leftoverProperties.size(", 
        leftoverProperties.size, ") != leftoverIndices.size(", leftoverIndices.size, ")");
    forall (prop, idx) in zip(leftoverProperties, leftoverIndices) {
      M.setProperty(prop, idx);
      A[idx].property = prop;
    }
  }

  /*
    Disable aggregation. This will cause all calls to `addInclusionBuffered` to go to `addInclusion` and
    all calls to `flush` to do a NOP.
  */
  config param AdjListHyperGraphDisableAggregation = false;

  /*
    This will forward all calls to the original instance rather than the privatized instance.
    This will result in severe communication overhead.
  */
  config param AdjListHyperGraphDisablePrivatization = false;

  /*
    Record-wrapper for the AdjListHyperGraphImpl. The record-wrapper follows from the optimization
    that Chapel's arrays, domains, and ranges use to eliminate communication that is inherent in
    in how Chapel represents pointers to potentially remote objects. Pointers in Chapel can be your
    normal 64-bit integer, or a widened 128-bit C struct, which holds both the 64-bit pointer
    as well as the locale id (32-bit integer) and a sublocale id (32-bit integer), the former used to
    describe the cluster node the memory is hosted on, and the latter describing the NUMA node the
    memory is allocated on. This is also the reason why you can declare a `atomic` class instance
    in Chapel.

    Since objects are hosted on a single node and do not migrate, a load and store to an object allocated
    in some other locale's address space will resolve to a GET and PUT respectively. Method invocation of
    a remote object is handled locally, but each load/store to the class fields are treated as remote PUT/GET,
    resulting in abysmal performance. To instruct that a method be performed on the locale that it is allocated
    on, care should be used that the body of the method is wrapped in an `on this` block. Note that it is not
    always appropriate to do this, as this creates a load imbalance and will result to degrading performance;
    as well, it has been found that with Cray's Aries Network Atomics, remote PUT/GET operations are significantly
    faster than remote execution. 

    The AdjListHyperGraph makes use of privatization, a process in which a local-copy of the object is created
    on each locale, documented as part of the DSI (Domain map Standard Interface). Privatization internally is
    implemented as a runtime table (C array), where the user can retrieve a privatized copy by the privatization
    id, the index into the table. Each copy will share the same privatization id so that it can be used across
    multiple locales; all locales will create a privatized copy, even the ones that the data structure is not
    intended to be distributed over. Calling `_newPrivatizedClass(this)` will create a privatized copy on each
    locale. Calling `chpl_getPrivatizedClass(this.type, pid)` where `pid` is the privatization id, will obtain
    the privatized instance for the current node to work on. Be aware that you must always access data through
    the privatized instance for performance sake, and that privatized instances, after creation, can be mutated
    independently of each other.

    Note also: arrays make use of a specific compiler-optimization for their record-wrappers called 'remote value
    forwarding' where the record is used by value in `forall` and `coforall` loops, rather than by reference.
    Since this is currently hard-coded for Chapel's arrays and domains, the user must manually make a copy of the
    record-wrapper to prevent it from being used by-reference, thereby negating the whole point of privatization.
    Hint: A reference to a remote object is treated as a wide pointer.
  */

  /*
    AdjListHyperGraph privatization wrapper; all access to this will forward to the privatized instance,
    :class:`AdjListHyperGraphImpl`.
  */
  pragma "always RVF"
  record AdjListHyperGraph {
    pragma "no doc"
    // Instance of our AdjListHyperGraphImpl from node that created the record
    var instance;
    pragma "no doc"
    // Privatization Id
    var pid = -1;

    pragma "no doc"
    proc _value {
      // If privatization is used, the privatization id must be at least 0
      if boundsChecking && pid == -1 {
        halt("AdjListHyperGraph is uninitialized...");
      }
      
      // If privatization is used, then return the privatized instance; else return the normal one
      return chpl_getPrivatizedCopy(instance.type, pid);
    }

    /*
      Create a new hypergraph with the desired number of vertices and edges. 
      Uses the 'DefaultDist', which is normally the shared-memory 'DefaultRectangularDist'.
    */
    proc init(numVertices : integral, numEdges : integral) {
      var dist = new unmanaged DefaultDist();
      init(numVertices, numEdges, dist, dist);
    }

    /*
      Create a new hypergraph with the desired number of vertices and edges, using
      the same distribution.
    */
    proc init(numVertices : integral, numEdges : integral, mapping) {
      init(numVertices, numEdges, mapping, mapping);
    }

    /*
      Create a hypergraph with a vertex property map and desired number of edges, with
      a default distribution.
    */
    proc init(vPropMap : PropertyMap(?vPropType), numEdges) {
      var dist = new unmanaged DefaultDist();
      init(vPropMap, dist, numEdges, dist);
    }

     /*
      Create a hypergraph with a vertex property map and desired number of edges, with
      the same distribution.
    */
    proc init(vPropMap : PropertyMap(?vPropType), numEdges, mapping) {
      init(vPropMap, mapping, numEdges, mapping);
    }


    /*
      Create a hypergraph with a edge property map and desired number of vertices, with
      a default distribution.
    */
    proc init(numVertices, ePropMap : PropertyMap(?ePropType)) {
      var dist = new unmanaged DefaultDist();
      init(numVertices, dist, ePropMap, dist);
    }

    /*
      Create a hypergraph with a edge property map and desired number of vertices, with
      the same distribution.
    */
    proc init(numVertices, ePropMap : PropertyMap(?ePropType), mapping) {
      init(numVertices, mapping, ePropMap, mapping);
    }

    /*
      Create a hypergraph with a edge and vertex property map with a default distribution.
    */
    proc init(vPropMap : PropertyMap(?vPropType), ePropMap : PropertyMap(?ePropType)) {
      var dist = new unmanaged DefaultDist();
      init(vPropMap, dist, ePropMap, dist);
    }

    /*
      Create a hypergraph with a edge and vertex property map with the same distribution.
    */
    proc init(vPropMap : PropertyMap(?vPropType), ePropMap : PropertyMap(?ePropType), mapping) {
      init(vPropMap, mapping, ePropMap, mapping);
    }

    /*
      Create a new hypergraph with the desired number of vertices and edges, and with
      their respective desired distributions.

      :arg numVertices: Number of vertices.
      :arg numEdges: Number of edges.
      :arg verticesMapping: Distribution of vertices.
      :arg edgesMapping: Distribution of edges.
    */
    proc init(
      // Number of vertices
      numVertices : integral,
      // Number of edges
      numEdges : integral,
      // Distribution of vertices
      verticesMappings, 
      // Distribution of edges
      edgesMappings
    ) {
      instance = new unmanaged AdjListHyperGraphImpl(
        numVertices, numEdges, verticesMappings, edgesMappings
      );
      pid = instance.pid;
    }

    /*
      Create a new hypergraph where vertices are determined via the property map and with
      the desired number of edges, along with their respective desired distributions.
      
      :arg vPropMap: PropertyMap for vertices.
      :arg vertexMappings: Distribution for vertices.
      :arg numEdges: Number of edges.
      :arg edgeMappings: Distribution for edges.
    */
    proc init(vPropMap : PropertyMap(?vPropType), vertexMappings, numEdges, edgeMappings) {
      instance = new unmanaged AdjListHyperGraphImpl(
        vPropMap, vertexMappings, numEdges, edgeMappings
      );
      pid = instance.pid;
    }

    /*
      Create a new hypergraph with the desired number of vertices, where hyperedges are 
      determined via the property map, along with their respective desired distributions.
      The number of vertices are determined from the number of properties for vertices. 
      
      :arg numVertices: Number of vertices.
      :arg vertexMappings: Distribution for vertices.
      :arg ePropMap: PropertyMap for edges.
      :arg edgeMappings: Distribution for edges.
    */    
    proc init(numVertices, vertexMappings, ePropMap : PropertyMap(?ePropType), edgeMappings) {
      instance = new unmanaged AdjListHyperGraphImpl(
        numVertices, vertexMappings, ePropMap, edgeMappings
      );
      pid = instance.pid;
    }

    /*
      Create a new hypergraph where hyperedges and vertices are 
      determined via their property map, along with their respective desired distributions.
      The number of vertices are determined from the number of properties for vertices. 
      
      :arg numVertices: Number of vertices.
      :arg vertexMappings: Distribution for vertices.
      :arg ePropMap: PropertyMap for edges.
      :arg edgeMappings: Distribution for edges.
    */    
    proc init(vPropMap : PropertyMap(?vPropType), vertexMappings, ePropMap : PropertyMap(?ePropType), edgeMappings) {
      instance = new unmanaged AdjListHyperGraphImpl(
        vPropMap, vertexMappings, ePropMap, edgeMappings
      );
      pid = instance.pid;
    }

    /*
      Performs a shallow copy of 'other' so that both 'this' and 'other' both
      refer to the same privatized instance.
      :arg other: Other :record:`AdjListHyperGraph` privatization wrapper.
    */
    proc init(other : AdjListHyperGraph) {
      instance = other.instance;
      pid = other.pid;
    }

    // TODO: Copy initializer produces an internal compiler error (compilation error after codegen),
    // Code that causes it: init(other.numVertices, other.numEdges, other.verticesDist)
    pragma "no doc"
    proc clone(other : this.type) {
      instance = new unmanaged AdjListHyperGraphImpl(other._value);
      pid = instance.pid;
    }
    
    /*
      Destroys the privatized instance;
      
      .. warning::

        If multiple privatized wrappers refer to the same privatized instance, this will delete
        the privatized instance for all of them, and hence this operation is not thread-safe.
    */
    proc destroy() {
      if boundsChecking && pid == -1 then halt("Attempt to destroy 'AdjListHyperGraph' which is not initialized...");
      coforall loc in Locales do on loc {
        delete chpl_getPrivatizedCopy(instance.type, pid);
      }
      pid = -1;
      instance = nil;
    }
    
    // Forwards to privatized instance
    forwarding _value;
  }
  
  /*
    Creates a hypergraph from the passed file name with the delimitor indicated by 'separator'. The hypergraph
    is given the provided distribution.

    :arg fileName: Name of file.
    :arg separator: Delimitor used in file.
    :arg map: Distribution.

    ..note ::

      This reader is purely naive and sequential, and hence should _not_ be used to read in large files.
      It is advised that instead that you use `BinReader`.

  */
  proc fromAdjacencyList(fileName : string, separator = ",", map : ?t = new unmanaged DefaultDist()) throws {
    var f = open(fileName, iomode.r);
    var r = f.reader();
    var vertices : [0..-1] int;
    var edges : [0..-1] int;

    for line in f.lines() {
      var (v,e) : 2 * int;
      var split = line.split(separator);
      if line == "" then continue;
      vertices.push_back(split[1] : int);
      edges.push_back(split[2] : int);
    }

    // Read in minimum and maximum
    var (vMin, vMax) = (max(int(64)), min(int(64)));
    var (eMin, eMax) =  (max(int(64)), min(int(64)));
    for (v,e) in zip(vertices, edges) {
      vMin = min(vMin, v);
      vMax = max(vMax, v);
      eMin = min(eMin, e);
      eMax = max(eMax, e);
    }

    // Convert to 0-based
    vertices -= vMin;
    edges -= eMin;

    // Initialize with data given...
    var graph = new AdjListHyperGraph(vMax - vMin + 1, eMax - eMin + 1, map);

    // Add inclusions...
    forall (v,e) in zip(vertices, edges) {
      graph.addInclusion(v,e);
    }

    return graph;
  }
  
  /*
    NodeData: stores the neighbor list of a node.

    Both vertices and hyperedges are represented by 'NodeData', and so are distinguished by
    the 'nodeIdType'. When a property map is used, we directly store the property inside of
    the NodeData for the vertex or hyperedge used for better locality. The NodeData uses a
    simple push-back vector, so duplicates must be removed first.
  */
  pragma "no doc"
  class NodeData {
    type nodeIdType;
    type propertyType;
    var property : propertyType;
    var incidentDomain = {0..1};
    var incident: [incidentDomain] int;
    var lock : Lock;
    var isSorted : bool;
    var size : atomic int;

    proc init(type nodeIdType, property : ?propertyType) {
      this.init(nodeIdType, propertyType);
      this.property = property;
    }

    proc init(type nodeIdType, type propertyType) {
      this.nodeIdType = nodeIdType;
      this.propertyType = propertyType;
    }

    proc init(other : NodeData(?nodeIdType, ?propertyType)) {
      this.nodeIdType = nodeIdType;
      this.propertyType = propertyType;
      complete();

      on other {
        other.lock.acquire();

        this.property = other.property;
        this.incidentDomain = other.incidentDomain;
        this.isSorted = other.isSorted;
        this.size.write(other.size.read());
        this.incident[0..#size.read()] = other.incident[0..#other.size.read()];

        other.lock.release();
      }
    }
    
    // Preallocates the incidence list to a certain size/capacity
    proc preallocate(sz : integral, param acquireLock = true) {
      if acquireLock then lock.acquire();
      
      local {
        if incidentDomain.size < sz {
          this.incidentDomain = {0..#sz};
        }
      }

      if acquireLock then lock.release();
    }
    
    // Check if both incidence lists are equal
    proc equals(other : this.type, param acquireLock = true) {
      if degree != other.degree then return false;
      // Acquire locks and update degree to be okay.
      if acquireLock {
        acquireLocks(lock, other.lock);
        if degree != other.degree {
          releaseLocks(lock, other.lock);
          return false;
        }
      }

      sortIncidence();
      other.sortIncidence();
      var retval = Utilities.arrayEquality(incident[0..#size.read()], other.incident[0..#other.size.read()]);
      
      if acquireLock then releaseLocks(lock, other.lock);
      return retval;
    }

    // Removes duplicates... sorts the incident list before doing so
    proc makeDistinct(param acquireLock = true) {
      if degree <= 1 then return 0;
      
      var incidenceRemoved = 0;
      on this {
        if acquireLock then lock.acquire();
        
        var deg = degree;
        sortIncidence();
        var newDom = {0..#size.read()};
        var newIncident : [newDom] int;
        var oldIdx : int;
        var newIdx : int;
        newIncident[newIdx] = incident[oldIdx];
        oldIdx += 1;
        while (oldIdx < deg) {
          if incident[oldIdx] != newIncident[newIdx] {
            newIdx += 1;
            newIncident[newIdx] = incident[oldIdx];
          }
          oldIdx += 1;
        }
        
        incidenceRemoved = deg - (newIdx + 1);
        incidentDomain = {0..newIdx};
        incident = newIncident[0..newIdx];
        size.write(newIdx + 1);
        
        if acquireLock then lock.release();
      }

      return incidenceRemoved;
    }

    // Checks to see if an S-Walk can be performed from this node to other.
    // This is much more lightweight compared to `neighborIntersection` as it
    // will short-circuit and will not create an intersection array.
    proc canWalk(other : this.type, s = 1, param acquireLock = true) {
      if this == other then halt("Attempt to walk on self... May be a bug!");
      if degree < s || other.degree < s then return false;

      if acquireLock then acquireLocks(lock, other.lock);
      sortIncidence();
      other.sortIncidence();
      
      var ret = Utilities.intersectionSizeAtLeast(this.incident, other.incident, s);
      
      if acquireLock then releaseLocks(lock, other.lock);
      
      return ret;
    }

    // Obtains the intersection of the neighbors of 'this' and 'other'.
    // Associative arrays are extremely inefficient, so we have to roll
    // our own intersection. We do this by sorting both data structures...
    // N.B: This may not perform well in distributed setting, but fine-grained
    // communications may or may not be okay here. Need to profile more.
    proc neighborIntersection(other : this.type, param acquireLock = true) {
      if this == other then halt("Attempt to obtain intersection on self... May be a bug!");
      // Acquire mutual exclusion on both
      if acquireLock then acquireLocks(lock, other.lock);
      sortIncidence();
      other.sortIncidence();

      var ret = Utilities.intersection(this.incident, other.incident);

      if acquireLock then releaseLocks(lock, other.lock);

      return ret;
    }

    proc intersectionSize(other : this.type, param acquireLock = true) {
      if this == other then halt("Attempt to walk on self... May be a bug!");

      if acquireLock then acquireLocks(lock, other.lock);
      sortIncidence();
      other.sortIncidence();

      var match = Utilities.intersectionSize(this.incident, other.incident);

      if acquireLock then releaseLocks(lock, other.lock);
      
      return match;
    } 


    // Sort the incidence list
    proc sortIncidence(param acquireLock = false) {
      on this do local {
        if acquireLock then lock.acquire();
        if !isSorted {
          sort(incident[0..#size.read()]);
          isSorted = true;
        }
        if acquireLock then lock.release();
      }
    }

    proc isIncident(n : nodeIdType, param acquireLock = true) {
      var retval : bool;
      const nid = n.id;
      on this {
        if acquireLock then lock.acquire();

        // Sort if not already
        sortIncidence();
        
        // Search to determine if it exists...
        var _retval : bool;
        const _nid = nid;
        local do _retval = search(incident, _nid, sorted = true)[1];

        if acquireLock then lock.release();
      }

      return retval;
    }

    inline proc isIncident(other) {
      Debug.badArgs(other, nodeIdType);
    }

    inline proc degree {
      return size.read();
    }

    inline proc cap {
      return incidentDomain.high;
    }

    // Resizes the incident list to at least 'sz'
    inline proc resize(sz = cap + 1) {
      on this {
        const _sz = sz;
        local {
          var newCap = ceil(cap * 1.5) : int;
          while newCap < _sz {
            newCap = ceil(newCap * 1.5) : int;
          }
          incidentDomain = {0..newCap};

        }
      }
    }

    /*
      This method is not parallel-safe with concurrent reads, but it is
      parallel-safe for concurrent writes.
    */
    inline proc addIncidence(ns : nodeIdType, param acquireLock = true) {
      const nid = ns.id;
      on this {
        const _nid = nid;
        local {
          if acquireLock then lock.acquire(); // acquire lock

          var ix = size.fetchAdd(1);
          if ix > cap {
            resize();
          }
          incident[ix] = _nid;
          isSorted = false;

          if acquireLock then lock.release(); // release the lock
        }
      }
    }
    
    proc this(idx : integral) ref {
      if boundsChecking && !incidentDomain.contains(idx) {
        halt("Out of Bounds: ", idx, " is not in ", 0..#size);
      }

      return incident[idx];
    }

    iter these() ref {
      for x in incident[0..#size.read()] do yield x;
    }

    iter these(param tag : iterKind) ref where tag == iterKind.standalone {
      forall x in incident[0..#size.read()] do yield x;
    }

    proc readWriteThis(f) {
      on this {
        lock.acquire();
        f <~> new ioLiteral("{ incident = ")
        	<~> these()
        	<~> new ioLiteral(") }");
        lock.release();
      }
    }
  }
  
  pragma "no doc"
  record ArrayWrapper {
    type eltType;
    var dom = {0..-1};
    var arr : [dom] eltType;
    var hash : uint;

    proc init(type eltType) {
      this.eltType = eltType;
    }

    proc init(arr : [?dom] ?eltType) {
      this.eltType = eltType;
      this.dom = dom;
      this.arr = arr;
      this.complete();
      for (ix, a) in zip(1.., arr) {
        // chpl__defaultHashCombine passed '17 + fieldnum' so we can only go up to 64 - 17 = 47
        this.hash = chpl__defaultHashCombine(chpl__defaultHash(a), this.hash, ix % 47);
      }
    }
  }

  pragma "no doc"
  proc ==(a: ArrayWrapper, b: ArrayWrapper) {
    if a.arr.size != b.arr.size then return false;
    for (_a, _b) in zip(a.arr,b.arr) do if _a != _b then return false;
    return true;
  }

  pragma "no doc"
  proc !=(a: ArrayWrapper, b: ArrayWrapper) {
    if a.arr.size != b.arr.size then return true;
    for (_a, _b) in zip(a.arr,b.arr) do if _a != _b then return true;
    return false;
  }

  pragma "no doc"
  inline proc chpl__defaultHash(r : ArrayWrapper): uint {
    return r.hash;
  }

  pragma "no doc"
  record Vertex {}
  pragma "no doc"
  record Edge   {}
 
  pragma "no doc"
  // Enables usage of vDescType and eDescType for associative arrays
  proc chpl__defaultHash(r : Wrapper) {
    return chpl__defaultHash(r.id);
  }

  pragma "always RVF"
  record Wrapper {
    type nodeType;
    type idType;
    var id: idType;

    /*
      Based on Brad's suggestion:

      https://stackoverflow.com/a/49951164/594274

      The idea is that we can call a function on the type.  In the
      cases where type is instantiated, we will know `nodeType` and
      `idType`, and we can just refer to them in our make method.
    */
    pragma "no doc"
    proc type make(id) {
      return new Wrapper(nodeType, idType, id);
    }
    
    // 'Null' value.
    proc type null() {
      return new Wrapper(nodeType, idType, -1);
    }
    
    proc readWriteThis(f) {
      f <~> new ioLiteral("\"")
        <~> nodeType : string
        <~> new ioLiteral("#")
        <~> id
        <~> new ioLiteral("\"");
    }

    forwarding id;
  }

  proc <(a : Wrapper(?nodeType, ?idType), b : Wrapper(nodeType, idType)) : bool {
    return a.id < b.id;
  }

  proc ==(a : Wrapper(?nodeType, ?idType), b : Wrapper(nodeType, idType)) : bool {
    return a.id == b.id;
  }

  proc !=(a : Wrapper(?nodeType, ?idType), b : Wrapper(nodeType, idType)) : bool {
    return a.id != b.id;
  }

  proc >(a : Wrapper(?nodeType, ?idType), b  : Wrapper(nodeType, idType)) : bool {
    return a.id > b.id;
  }

  // Enable casts from wrappers to integers
  proc _cast(type t: Wrapper(?nodeType, ?idType), id : integral) {
    return t.make(id : idType);
  }

  // Enable cast to itself
  proc _cast(type t: Wrapper(?nodeType, ?idType), id : Wrapper(nodeType, idType)) {
    return id;
  }
  
  pragma "no doc"
  inline proc _cast(type t: Wrapper(?nodeType, ?idType), id) {
    compilerError("Bad cast from type ", id.type : string, " to ", t : string, "...");
  }
  
  // Obtain the identifier from a wrapper.
  inline proc id ( wrapper ) {
    return wrapper.id;
  }

  pragma "no doc"  
  enum InclusionType { Vertex, Edge }

  /*
     Adjacency list hypergraph.

     The storage is an array of NodeDatas.  The edges array stores edges, and
     the vertices array stores vertices.  The storage is similar to a
     bidirectional bipartite graph.  Every edge has a set of vertices it
     contains, and every vertex has a set of edges it participates in.  In terms
     of matrix storage, we store CSR and CSC and the same time.  Storing
     strictly CSC or CSR would allow cutting the storage in half, but for now
     the assumption is that having the storage go both ways should allow
     optimizations of certain operations.
  */
  class AdjListHyperGraphImpl {
    pragma "no doc"
    var _verticesDomain; // domain of vertices
    pragma "no doc"
    var _edgesDomain; // domain of edges
    pragma "no doc"
    type _vPropType; // Vertex property
    pragma "no doc"
    type _ePropType; // Edge property
  
    // Privatization id
    pragma "no doc"
    var pid = -1;
    
    // Index type for vertices; matches the type of indices for the vertex domain (currently int(64))
    type vIndexType = index(_verticesDomain);
    // Index type for hyperedges; matches the type of indices for the hyperedges domain (currently int(64))
    type eIndexType = index(_edgesDomain);
    // Type of the wrapper for a vertex.
    type vDescType = Wrapper(Vertex, vIndexType);
    // Type of the wrapper for a edge.
    type eDescType = Wrapper(Edge, eIndexType);

    pragma "no doc"
    var _vertices : [_verticesDomain] unmanaged NodeData(eDescType, _vPropType);
    pragma "no doc"
    var _edges : [_edgesDomain] unmanaged NodeData(vDescType, _ePropType);
    pragma "no doc"
    var _destBuffer = UninitializedAggregator((vIndexType, eIndexType, InclusionType));
    pragma "no doc"
    var _vPropMap : PropertyMap;
    pragma "no doc"
    var _ePropMap : PropertyMap;
    pragma "no doc"
    var _privatizedVertices = _vertices._value;
    pragma "no doc"
    var _privatizedEdges = _edges._value;
    pragma "no doc"
    var _privatizedVerticesPID = _vertices.pid;
    pragma "no doc"
    var _privatizedEdgesPID = _edges.pid;
    pragma "no doc"
    var _useAggregation : bool;

    pragma "no doc"
    /*
      The main initializer; all other initializers should call this after filling out the appropriate parameters.
    */
    proc init(numVertices : int, vPropMap : PropertyMap(?vPropType), vertexMappings, numEdges : int,  ePropMap : PropertyMap(?ePropType), edgeMappings) {
      // Ensure that arguments are non-negative
      if numVertices < 0 { 
        halt("numVertices must be between 0..", max(int(64)), " but got ", numVertices);
      }
      if numEdges < 0 { 
        halt("numEdges must be between 0..", max(int(64)), " but got ", numEdges);
      }
      
      // Initialize vertices and edges domain; once `this.complete()` is invoked, the
      // array itself will also be initialized.
      this._verticesDomain = {0..#numVertices} dmapped new dmap(vertexMappings);
      this._edgesDomain = {0..#numEdges} dmapped new dmap(edgeMappings);
      
      this._vPropType = vPropType;
      this._ePropType = ePropType;
      this._destBuffer = new Aggregator((vIndexType, eIndexType, InclusionType));
      this._vPropMap = vPropMap;
      this._ePropMap = ePropMap;

      // Done initializing generic type fields.
      this.complete();
      
      // Initialize vertices and edges
      [v in _vertices] v = new unmanaged NodeData(eDescType, _vPropType);
      [e in _edges] e = new unmanaged NodeData(vDescType, _ePropType);

      // If the property map is initialized (I.E not UninitializedPropertyMap)
      // we need to assign them the appropriate vertices.
      if _vPropMap.isInitialized {
        _vertices = _vPropMap;
      }
      if _ePropMap.isInitialized {
        _edges = _ePropMap;
      }
      this.pid = _newPrivatizedClass(_to_unmanaged(this));
    }



    pragma "no doc"
    proc init(numVertices = 0, numEdges = 0, vertexMappings, edgeMappings) {
      const pmap = UninitializedPropertyMap(bool);
      init(numVertices, pmap, vertexMappings, numEdges, pmap, edgeMappings);
    }

    pragma "no doc"
    proc init(vPropertyMap : PropertyMap(?vPropType), vertexMappings, numEdges = 0, edgeMappings) {
      const pmap = UninitializedPropertyMap(bool);
      init(vPropertyMap.numProperties(), vPropertyMap, vertexMappings, numEdges, pmap, edgeMappings);
    }

    pragma "no doc"
    proc init(vPropertyMap : PropertyMap(?vPropType), vertexMappings, numEdges = 0, edgeMappings) {
      const pmap = UninitializedPropertyMap(bool);
      init(vPropertyMap.numProperties(), vPropertyMap, vertexMappings, numEdges, pmap, edgeMappings);
    }

    pragma "no doc"
    proc init(vPropertyMap : PropertyMap(?vPropType), vertexMappings, ePropertyMap : PropertyMap(?ePropType), edgeMappings) {
      init(vPropertyMap.numProperties(), vPropertyMap, vertexMappings, ePropertyMap.numProperties(), ePropertyMap, edgeMappings);
    }

    pragma "no doc"
    proc init(numVertices = 0, vertexMappings, ePropertyMap : PropertyMap(?ePropType), edgeMappings) {
      const pmap = UninitializedPropertyMap(bool);
      init(numVertices, pmap, vertexMappings, ePropertyMap.numProperties(), ePropertyMap, edgeMappings);
    }

    // Note: Do not create a copy initializer as it is called whenever you create a copy
    // of the object. This is undesirable.
    pragma "no doc"
    proc clone(other : AdjListHyperGraphImpl) {
      const verticesDomain = other._verticesDomain;
      const edgesDomain = other._edgesDomain;
      this._verticesDomain = verticesDomain;
      this._edgesDomain = edgesDomain;
      this._vPropType = other._vPropType;
      this._ePropType = other._ePropType;
      this._destBuffer = other._destBuffer;
      this._vPropMap = new PropertyMap(other._vPropMap);
      this._ePropMap = new PropertyMap(other._ePropMap);
  
      // Done initializing generic types
      this.complete();
      
      forall (ourV, theirV) in zip(this._vertices, other._vertices) do ourV = new unmanaged NodeData(theirV);
      forall (ourE, theirE) in zip(this._edges, other._edges) do ourE = new unmanaged NodeData(theirE);     
      this.pid = _newPrivatizedClass(_to_unmanaged(this));
    }

    pragma "no doc"
    proc init(other : AdjListHyperGraphImpl, privatizedData) {
      var verticesDomain = other._verticesDomain;
      var edgesDomain = other._edgesDomain;
      verticesDomain.clear();
      edgesDomain.clear();
      this._verticesDomain = verticesDomain;
      this._edgesDomain = edgesDomain;
      this._vPropType = other._vPropType;
      this._ePropType = other._ePropType;
      this._destBuffer = other._destBuffer;
      this._vPropMap = privatizedData[7];
      this._ePropMap = privatizedData[8];
    
      complete();

      this.pid = privatizedData[1];
      if here == Locales[0] {
        halt("AdjListHyperGraph not created on Locale #0!");
      }
      this._privatizedVerticesPID = privatizedData[3];
      this._privatizedEdgesPID = privatizedData[5];
      this._privatizedVertices = if _isPrivatized(_vertices._instance) then chpl_getPrivatizedCopy(privatizedData[2].type, privatizedData[3]) else privatizedData[2];
      this._privatizedEdges = if _isPrivatized(_edges._instance) then chpl_getPrivatizedCopy(privatizedData[4].type, privatizedData[5]) else privatizedData[4];
      this._destBuffer = privatizedData[6];
    }
    
    pragma "no doc"
    proc deinit() {
      // Only delete data from master locale
      if here == Locales[0] {
        _destBuffer.destroy();
        [v in _verticesDomain] delete _vertices[v];
        [e in _edgesDomain] delete _edges[e];
      }
    }

    pragma "no doc"
    proc dsiPrivatize(privatizedData) {
      return new unmanaged AdjListHyperGraphImpl(this, privatizedData);
    }

    pragma "no doc"
    proc dsiGetPrivatizeData() {
      return (pid, _privatizedVertices, _privatizedVerticesPID, _privatizedEdges, _privatizedEdgesPID, _destBuffer, _vPropMap, _ePropMap);
    }

    pragma "no doc"
    inline proc getPrivatizedInstance() {
      return chpl_getPrivatizedCopy(this.type, pid);
    }
    
    /*
      Obtain the domain of vertices; each index of the domain is a vertex id.
    */
    inline proc verticesDomain {
      return _getDomain(_to_unmanaged(vertices.dom));
    }
    
    /*
      Obtain the domain of hyperedges; each index of the domain is a hyperedge id.
    */
    inline proc edgesDomain {
      return _getDomain(_to_unmanaged(edges.dom));
    }
    
    pragma "no doc"    
    inline proc vertices {
      if boundsChecking {
        if _privatizedVertices == nil {
          halt(here, " has a nil _privatizedVertices");
        }
      }
      return _privatizedVertices;
    }

    pragma "no doc"    
    inline proc edges {
      if boundsChecking {
        if _privatizedEdges == nil {
          halt(here, " has a nil _privatizedEdges");
        }
      }
      return _privatizedEdges;
    }

    pragma "no doc"
    inline proc getVertex(idx : integral) ref {
      return getVertex(toVertex(idx));
    }

    pragma "no doc"
    inline proc getVertex(desc : vDescType) ref {
      return vertices.dsiAccess(desc.id);
    }

    pragma "no doc"
    inline proc getVertex(other) {
      Debug.badArgs(other, (vIndexType, vDescType));  
    }

    pragma "no doc"
    inline proc getEdge(idx : integral) ref {
      return getEdge(toEdge(idx));
    }

    pragma "no doc"
    inline proc getEdge(desc : eDescType) ref {
      return edges.dsiAccess(desc.id);
    }
    
    pragma "no doc"
    inline proc getEdge(other) {
      Debug.badArgs(other, (eIndexType, eDescType));  
    }

    pragma "no doc"
    inline proc verticesDist {
      return _to_unmanaged(verticesDomain.dist);
    }

    pragma "no doc"
    inline proc edgesDist {
      return _to_unmanaged(edgesDomain.dist);
    }

    pragma "no doc"
    inline proc useAggregation {
      return _useAggregation;
    }

    pragma "no doc"
    proc isPrivatized() param {
      return _isPrivatized(_vertices._instance) || _isPrivatized(_edges._instance);
    }
    
    /*
      Obtain the number of edges in the graph.
    */
    inline proc numEdges return edgesDomain.size;
    
    /*
      Obtain the number of vertices in the graph.
    */
    inline proc numVertices return verticesDomain.size;
    
    /*
      Obtain degree of the vertex.
    */
    inline proc degree(vDesc : vDescType) return getVertex(vDesc).degree;
    /*
      Obtain degree of the hyperedge.
    */
    inline proc degree(eDesc : eDescType) return getEdge(eDesc).degree;
    pragma "no doc"
    inline proc degree(other) {
      Debug.badArgs(other, (vDescType, eDescType));
    }
    
    /*
      Iterator that yields all edges we can s-walk to. We can s-walk from an edge e to
      another edge e' if the size of the intersection of both e and e' is at least s.

      :arg eDesc: The edge to s-walk from.
    */
    iter walk(eDesc : eDescType, s = 1) : eDescType {
      for v in incidence(eDesc) {
        for e in incidence(v) {
          if eDesc != e && (s == 1 || isConnected(eDesc, e, s)) {
            yield e;
          }
        }
      }
    }
    
    
    iter walk(eDesc : eDescType, s = 1, param tag : iterKind) : eDescType where tag == iterKind.standalone {
      forall v in incidence(eDesc) {
        forall e in incidence(v) {
          if eDesc != e && (s == 1 || isConnected(eDesc, e, s)) {
            yield e;
          }
        }
      }
    }
    
    /*
      Iterator that yields all vertices we can s-walk to. We can s-walk from an vertex v to
      another vertex v' if the size of the intersection of both v and v' is at least s.

      :arg vDesc: The vertex to s-walk from.
    */
    iter walk(vDesc : vDescType, s = 1) : vDescType {
      for e in incidence(vDesc) {
        for v in incidence(e) {
          if vDesc != v && (s == 1 || isConnected(vDesc, v, s)) {
            yield v;
          }
        }
      }
    }

    iter walk(vDesc : vDescType, s = 1, param tag : iterKind) : vDescType where tag == iterKind.standalone {
      forall e in incidence(vDesc) {
        forall v in incidence(e) {
          if vDesc != v && (s == 1 || isConnected(vDesc, v, s)) {
            yield v;
          }
        }
      }
    }

    /*
      Yield toplex hyperedges in the graph. A hyperedge e is a toplex if there exists no other
      hyperedge e' such that e' is a superset of e; that is, e is a hyperedge that is not a subset
      of any other edge.
    */
    iter getToplexes() {
      var notToplex : [edgesDomain] bool;
      for e in getEdges() {
        var n = degree(e);
        if notToplex[e.id] then continue;
        for ee in walk(e, n) {
          if degree(ee) == n && isConnected(e, ee, n) {
            notToplex[ee.id] = true;
          } else {
            notToplex[e.id] = true;
            break;
          }
        }
        if !notToplex[e.id] then yield e;
      }
    }

    iter getToplexes(param tag : iterKind) where tag == iterKind.standalone {
      var notToplex : [edgesDomain] bool;
      forall e in getEdges() {
        var n = degree(e);
        if notToplex[e.id] then continue;
        for ee in walk(e, n) {
          if degree(ee) == n && isConnected(e, ee, n) {
            notToplex[ee.id] = true;
          } else {
            notToplex[e.id] = true;
            break;
          }
        }
        if !notToplex[e.id] then yield e;
      }
    }

    /*
      Obtain the property associated with a vertex.

      :arg vDesc: Vertex to obtain the property of.
    */
    proc getProperty(vDesc : vDescType) : _vPropType {
      if !_vPropMap.isInitialized then halt("No vertex property map is created for this hypergraph!");
      return getVertex(vDesc).property;
    }

    /*
      Obtain the property associated with a edge.

      :arg eDesc: Edge to obtain the property of.
    */
    proc getProperty(eDesc : eDescType) : _ePropType {
      if !_ePropMap.isInitialized then halt("No edge property map is created for this hypergraph");
      return getEdge(eDesc).property;
    }

    pragma "no doc"
    inline proc getProperty(other) {
      Debug.badArgs(other, (vDescType, eDescType));
    }
    
    /* 
      Simplify vertices in graph by collapsing duplicate vertices into equivalence
      classes. This updates the property map, if there is one, to update all references
      to vertices to point to the new candidate. This is an inplace operation. Must
      be called from Locale #0. Returns a histogram of duplicates.
    */
    proc collapseVertices() {
      // Enforce on Locale 0 (presumed master locale...)
      if here != Locales[0] {
        halt("Collapse must be performed on master locale #0");
      }

      const __verticesDomain = _verticesDomain;
      var duplicateVertices : [__verticesDomain] atomic int;
      [dup in duplicateVertices] dup.write(-1);
      var newVerticesDomain = __verticesDomain;
      var vertexMappings : [__verticesDomain] int = -1;

      //writeln("Collapsing Vertices...");
      // Pass 1: Locate duplicates by performing an s-walk where s is the size of current vertex
      // We impose an ordering on determining what vertex is a duplicate of what. A vertex v is a
      // duplicate of a vertex v' if v.id > v'.id. If there is a vertex v'' such that v''.id > v.id
      // and v''.id < v'.id, that is v.id < v''.id < v'.id, the duplicate marking is still preserved
      // as we can follow v'.id's duplicate to find v''.id's duplicate to find the distinct vertex v.
      {
        //writeln("Marking and Deleting Vertices...");
        // TODO: Optimize!
        // Step 1: Optimize for Locality first! Spawn one task per core per locale, and
        // on each task, have them create equivalence classes for the matching vertices
        // and edges.
        // Step 2: Take pairs of tasks and handle merging their equivalent classes into a single
        // into a single equivalence class. This should be performed across each locale and in
        // parallel across multiple cores if possible. 
        // Step 3: Take pairs of locales and handle merging their equivalent classes into a single
        // equivalence class. Then count the number of unique vertices.
        var eqclass = new unmanaged Equivalence(int, ArrayWrapper(int));
        
        var redux = eqclass.reduction();
        forall v in _verticesDomain with (redux reduce eqclass) {
          var _this = getPrivatizedInstance();
          var _v = _this.toVertex(v);
          var tmp = [e in _this.incidence(_v)] e.id;
          sort(tmp);
          eqclass.add(v, new ArrayWrapper(tmp));
        }
        
        var numUnique : int;
        forall leader in eqclass.getEquivalenceClasses() with (+ reduce numUnique) {
          numUnique += 1;
          for follower in eqclass.getCandidates(leader) {
            delete _vertices[follower];
            _vertices[follower] = nil;
            duplicateVertices[follower].write(leader);
          }
        }
        delete eqclass;
        
        // No need to simplify
        if _verticesDomain.size == numUnique {
          var ret : [1..0] int;
          return ret;
        }

        newVerticesDomain = {0..#numUnique};
        //writeln(
        //  "Unique Vertices: ", numUnique, 
        //  ", Duplicate Vertices: ", _verticesDomain.size - numUnique, 
        //  ", New Vertices Domain: ", newVerticesDomain
        //);

        // Verification...
        if Debug.ALHG_DEBUG {
          forall v in _verticesDomain {
            var vv = v;
            while _vertices[vv] == nil {
              vv = duplicateVertices[vv].read();
              assert(vv != -1, "A vertex is nil without a duplicate mapping...");
            }
            var containsVV : bool;
            label outer for e in _vertices[vv].these() {
              for vvv in _edges[e.id] {
                if vvv.id == vv {
                  containsVV = true;
                  break outer;
                }
              }
            }
            if !containsVV {
              writeln("Broken Dual!");
              var vvv = v;
              write("Link: ", toVertex(v));
              while _vertices[vvv] == nil {
                vvv = duplicateVertices[vvv].read();
                write(" -> ", toVertex(vvv));
              }
              writeln();

              writeln("Neighborhood of ", toVertex(vv));
              for e in getVertex(vv) {
                writeln("\t", toEdge(e), ":", [_v in getEdge(e)] _v : string + ",");
              }
            }
          }
        }
      }

      writeln("Moving into temporary array...");
      // Move current array into auxiliary...
      const oldVerticesDom = this._verticesDomain;
      var oldVertices : [oldVerticesDom] unmanaged NodeData(eDescType, _vPropType) = this._vertices;
      this._verticesDomain = newVerticesDomain;

      writeln("Shifting down NodeData for Vertices...");
      // Pass 2: Move down unique NodeData into 'nil' spots. In parallel we will
      // claim indices in the new array via an atomic counter.
      {
        // Optimize! Claim atomic indices in bulk by processing the locale's local subdomain
        // and claiming them all at once. Also try to match the distribution of the original
        // array; hence, try to first claim indices that are local in _both_ new and old arrays.
        var idx : atomic int;
        forall v in oldVertices.domain {
          if oldVertices[v] != nil {
            var ix = idx.fetchAdd(1);

            // If the locations in the old and new array are the same, we just move it over
            if oldVertices[v].locale == _vertices[ix].locale {
              _vertices[ix] = oldVertices[v];
            } 
            // If the locations are different, we make a copy of the NodeData so that it is local
            // to the new locale.
            else on _vertices[ix] {
              _vertices[ix] = new unmanaged NodeData(oldVertices[v]);
              delete oldVertices[v];
            }

            oldVertices[v] = nil;
            vertexMappings[v] = ix;
          }
        }
        writeln("Shifted down to idx ", idx.read(), " for oldVertices.domain = ", oldVertices.domain);
      }
      
      writeln("Redirecting references to Vertices...");
      // Pass 3: Redirect references to collapsed vertices to new mappings
      {
        forall e in _edges {
          for v in e {
            // If the vertex has been collapsed, first obtain the id of the vertex it was collapsed
            // into, and then obtain the mapping for the collapsed vertex. Otherwise just
            // get the mapping for the unique vertex.
            while duplicateVertices[v].read() != -1 {
              v = duplicateVertices[v].read();
            }
            v = vertexMappings[v];
          }
        }
      }
      
      if _vPropMap.isInitialized {
        writeln("Updating PropertyMap...");
        // Pass 4: Update PropertyMap
        {
          writeln("Updating PropertyMap for Vertices...");
          forall vIdx in _vPropMap.values {
            if vIdx != -1 {
              vIdx = vertexMappings[vIdx];
            }
          }
        }
      }

      writeln("Removing duplicates: ", removeDuplicates());
      removeDuplicates();

      // Obtain duplicate stats...
      var numDupes : [_verticesDomain] atomic int;
      forall vDup in duplicateVertices {
        if vDup.read() != -1 {
          numDupes[vertexMappings[vDup.read()]].add(1);
        }
      }

      var maxDupes = max reduce [n in numDupes] n.read();
      var dupeHistogram : [1..maxDupes] atomic int;
      forall nDupes in numDupes do if nDupes.read() != 0 then dupeHistogram[nDupes.read()].add(1);
      return [n in dupeHistogram] n.read();
    }

    /* 
      Simplify edges in graph by collapsing duplicate edges into equivalence
      classes. This updates the property map, if there is one, to update all references
      to vertices to point to the new candidate. This is an inplace operation. Must be
      called from Locale #0. Returns a histogram of duplicates
    */
    proc collapseEdges() {
      // Enforce on Locale 0 (presumed master locale...)
      if here != Locales[0] {
        // Cannot jump and return as return type is inferred by compiler.
        halt("Collapse must be performed on master locale #0");
      }

      const __edgesDomain = _edgesDomain;
      var duplicateEdges : [__edgesDomain] atomic int;
      [dup in duplicateEdges] dup.write(-1);
      var newEdgesDomain = __edgesDomain;
      var edgeMappings : [__edgesDomain] int = -1;

      

      //writeln("Collapsing Edges...");
      // Pass 1: Locate duplicates by performing an s-walk where s is the size of current edge
      // We impose an ordering on determining what edge is a duplicate of what. A edge e is a
      // duplicate of a edge e' if e.id > e'.id. If there is a edge e'' such that e''.id > e.id
      // and e''.id < e'.id, that is e.id < e''.id < e'.id, the duplicate marking is still preserved
      // as we can follow e'.id's duplicate to find e''.id's duplicate to find the distinct edge e.
      {
        //writeln("Marking and Deleting Edges...");
        var eqclass = new unmanaged Equivalence(int, ArrayWrapper(int));
        var redux = eqclass.reduction();
        forall e in _edgesDomain with (redux reduce eqclass) {
          var _this = getPrivatizedInstance();
          var _e = _this.toEdge(e);
          var tmp = [v in _this.incidence(_e)] v.id;
          sort(tmp);
          eqclass.add(e, new ArrayWrapper(tmp));
        }
        
        var numUnique : int;
        forall leader in eqclass.getEquivalenceClasses() with (+ reduce numUnique) {
          numUnique += 1;
          for follower in eqclass.getCandidates(leader) {
            delete _edges[follower];
            _edges[follower] = nil;
            duplicateEdges[follower].write(leader);
          }
        }
        delete eqclass;
        
        // No duplicates, just return
        if _edgesDomain.size == numUnique {
          var ret : [1..0] int;
          return ret;
        }
        newEdgesDomain = {0..#numUnique};
        //writeln(
        //  "Unique Edges: ", numUnique, 
        //  ", Duplicate Edges: ", _edgesDomain.size - numUnique, 
        //  ", New Edges Domain: ", newEdgesDomain
        //);

        // Verification...
        if Debug.ALHG_DEBUG {
          forall e in _edgesDomain {
            var ee = e;
            while _edges[ee] == nil {
              ee = duplicateEdges[ee].read();
              assert(ee != -1, "An edge is nil without a duplicate mapping...");
            }
            var containsEE : bool;
            label outer for v in _edges[ee].these() {
              for eee in _vertices[v.id] {
                if eee.id == ee {
                  containsEE = true;
                  break outer;
                }
              }
            }

            if !containsEE {
              writeln("Broken Dual!");
              var eee = e;
              write("Link: ", toEdge(e));
              while _edges[eee] == nil {
                eee = duplicateEdges[eee].read();
                write(" -> ", toEdge(eee));
              }
              writeln();

              writeln("Neighborhood of ", toEdge(ee));
              for v in getEdge(ee) {
                writeln("\t", toVertex(v), ":", [_e in getVertex(v)] _e : string + ",");
              }
            }
          }
        }
      }

      //writeln("Moving into temporary array...");
      // Move current array into auxiliary...
      const oldEdgesDom = this._edgesDomain;
      var oldEdges : [oldEdgesDom] unmanaged NodeData(vDescType, _ePropType) = this._edges;
      this._edgesDomain = newEdgesDomain;

      //writeln("Shifting down NodeData for Edges...");
      // Pass 2: Move down unique NodeData into 'nil' spots. In parallel we will
      // claim indices in the new array via an atomic counter.
      {
        var idx : atomic int;
        forall e in oldEdges.domain {
          if oldEdges[e] != nil {
            var ix = idx.fetchAdd(1);
            
            if oldEdges[e].locale == _edges[ix].locale {
              _edges[ix] = oldEdges[e];
            } else on _edges[ix] {
              _edges[ix] = new unmanaged NodeData(oldEdges[e]);
              delete oldEdges[e];
            }
            
            oldEdges[e] = nil;
            edgeMappings[e] = ix;
          }
        }
        //writeln("Shifted down to idx ", idx.read(), " for oldEdges.domain = ", oldEdges.domain);
      }
      
      //writeln("Redirecting references to Edges...");
      // Pass 3: Redirect references to collapsed vertices and edges to new mappings
      {
        forall v in _vertices {
          for e in v {
            // If the edge has been collapsed, first obtain the id of the edge it was collapsed
            // into, and then obtain the mapping for the collapsed edge. Otherwise just
            // get the mapping for the unique edge.
            while duplicateEdges[e].read() != -1 {
              e = duplicateEdges[e].read();
            }
            e = edgeMappings[e];
          }
        }
      }
      
      if _ePropMap.isInitialized {
        //writeln("Updating PropertyMap for Edges...");
        // Pass 4: Update PropertyMap
        {
          forall eIdx in _ePropMap.values {
            if eIdx != -1 then eIdx = edgeMappings[eIdx];
          }
        }
      }
      
      //writeln("Removing duplicates: ", removeDuplicates());
      removeDuplicates();

      // Obtain duplicate stats...
      var numDupes : [_edgesDomain] atomic int;
      forall eDup in duplicateEdges {
        if eDup.read() != -1 {
          numDupes[edgeMappings[eDup.read()]].add(1);
        }
      }

      var maxDupes = max reduce [n in numDupes] n.read();
      var dupeHistogram : [1..maxDupes] atomic int;
      forall nDupes in numDupes do if nDupes.read() != 0 then dupeHistogram[nDupes.read()].add(1);
      return [n in dupeHistogram] n.read();
    }
    
    /*
      Collapses hyperedges into the equivalence class of the toplex they are apart of.
      This updates the property map, if there is one, to update all references
      to vertices to point to the new candidate. This is an inplace operation. Must be
      called from Locale #0. Returns a histogram representing the number of edges collapsed
      into toplexes.
    */
    proc collapseSubsets() {
      // Enforce on Locale 0 (presumed master locale...)
      if here != Locales[0] {
        // Cannot jump and return as return type is inferred by compiler.
        halt("Collapse must be performed on master locale #0");
      }

      const __edgesDomain = _edgesDomain;
      var toplexEdges : [__edgesDomain] atomic int;
      [toplex in toplexEdges] toplex.write(-1);
      var newEdgesDomain = __edgesDomain;
      var edgeMappings : [__edgesDomain] int = -1;

      writeln("Collapsing Subset...");
      {
        writeln("Marking non-toplex edges...");
        forall e in _edgesDomain do if toplexEdges[e].read() == -1 {
          label look for v in _edges[e] {
            if toplexEdges[e].read() != -1 then break look;
            for ee in _vertices[v] do if e != ee && toplexEdges[ee].read() == -1 {
              if _edges[e].canWalk(_edges[ee], s=_edges[e].degree) {
                if _edges[e].degree > _edges[ee].degree {
                  toplexEdges[ee].write(e);
                } else if _edges[ee].degree > _edges[e].degree {
                  toplexEdges[e].write(ee);
                  break look;
                } else if e < ee {
                  // Same size, greater priority
                  toplexEdges[ee].write(e);
                } else if ee > e {
                  toplexEdges[e].write(ee);
                }
              }
            }
          }
        }

        writeln("Deleting non-toplex edges...");
        var numToplex : int;
        forall e in _edgesDomain with (+ reduce numToplex) {
          if toplexEdges[e].read() != -1 {
            delete _edges[e];
            _edges[e] = nil;
          } else {
            numToplex += 1;
          }
        }
        
        newEdgesDomain = {0..#numToplex};
        writeln(
          "Toplex Edges: ", numToplex, 
          ", Non-Toplex Edges: ", _edgesDomain.size - numToplex, 
          ", New Edges Domain: ", newEdgesDomain
        );
      }

      writeln("Moving into temporary array...");
      // Move current array into auxiliary...
      const oldEdgesDom = this._edgesDomain;
      var oldEdges : [oldEdgesDom] unmanaged NodeData(vDescType, _ePropType) = this._edges;
      this._edgesDomain = newEdgesDomain;

      writeln("Shifting down NodeData for Edges...");
      // Pass 2: Move down unique NodeData into 'nil' spots. In parallel we will
      // claim indices in the new array via an atomic counter.
      {
        var idx : atomic int;
        forall e in oldEdges.domain {
          if oldEdges[e] != nil {
            var ix = idx.fetchAdd(1);
            
            if oldEdges[e].locale == _edges[ix].locale {
              _edges[ix] = oldEdges[e];
            } else on _edges[ix] {
              _edges[ix] = new unmanaged NodeData(oldEdges[e]);
              delete oldEdges[e];
            }
            
            oldEdges[e] = nil;
            edgeMappings[e] = ix;
          }
        }
        writeln("Shifted down to idx ", idx.read(), " for oldEdges.domain = ", oldEdges.domain);
      }
      
      writeln("Redirecting references to Edges...");
      // Pass 3: Redirect references to collapsed vertices and edges to new mappings
      {
        forall v in _vertices {
          for e in v {
            // If the edge has been collapsed, first obtain the id of the edge it was collapsed
            // into, and then obtain the mapping for the collapsed edge. Otherwise just
            // get the mapping for the unique edge.
            while toplexEdges[e].read() != -1 {
              e = toplexEdges[e].read();
            }
            e = edgeMappings[e];
          }
        }
      }
      
      if _ePropMap.isInitialized {
        writeln("Updating PropertyMap for Edges...");
        // Pass 4: Update PropertyMap
        {
          forall eIdx in _ePropMap.values {
            if eIdx != -1 {
              var toplexId = eIdx;
              while toplexEdges[toplexId].read() != -1 {
                toplexId = toplexEdges[toplexId].read();
              }
              eIdx = edgeMappings[eIdx];
            } 
          }
        }
      }

      writeln("Removing duplicates: ", removeDuplicates());

      // Obtain toplex stats...
      var numDupes : [_edgesDomain] atomic int;
      forall toplex in toplexEdges {
        if toplex.read() != -1 {
          var toplexId = toplex.read();
          while toplexEdges[toplexId].read() != -1 {
            toplexId = toplexEdges[toplexId].read();
          }
          numDupes[edgeMappings[toplexId]].add(1);
        }
      }

      var maxDupes = max reduce [n in numDupes] n.read();
      var dupeHistogram : [1..maxDupes] atomic int;
      forall nDupes in numDupes do if nDupes.read() != 0 then dupeHistogram[nDupes.read()].add(1);
      return [n in dupeHistogram] n.read();
    }
    
    /*
      Equivalent to a call to `collapseVertices` and `collapseEdges`; returns the histogram
      of vertices and edges (vDuplicateHistogram, eDuplicateHistogram)
    */
    proc collapse() {
      var vDupeHistogram = collapseVertices();
      writeln("Collapsed vertices");
      if Debug.ALHG_DEBUG {
        forall v in getVertices() {
          assert(getVertex(v) != nil, "Vertex ", v, " is nil...");
          assert(degree(v) > 0, "Vertex has 0 neighbors...");
          forall e in incidence(v) {
            assert(getEdge(e) != nil, "Edge ", e, " is nil...");
            assert(degree(e) > 0, "Edge has 0 neighbors...");

            var isValid : bool;
            for vv in incidence(e) {
              if vv == v {
                isValid = true;
                break;
              }
            }

            assert(isValid, "Vertex ", v, " has neighbor ", e, " that violates dual property...\nNeighbors = ", incidence(e));
          }
        }

        forall e in getEdges() {
          assert(getEdge(e) != nil, "Edge ", e, " is nil...");
          assert(degree(e) > 0, "Edge has 0 neighbors...");
          forall v in incidence(e) {
            assert(getVertex(v) != nil, "Vertex ", v, " is nil...");
            assert(degree(v) > 0, "Vertex has 0 neighbors...");

            var isValid : bool;
            for ee in incidence(v) {
              if ee == e {
                isValid = true;
                break;
              }
            }

            assert(isValid, "Edge ", e, " has neighbor ", v, " that violates dual property...\n"
             + "Neighbors of ", v, " = ", incidence(v), "\nNeighbors of ", e, " = ", incidence(e));
          }
        }
      }
      
      var eDupeHistogram = collapseEdges();
      if Debug.ALHG_DEBUG {
        forall v in getVertices() {
          assert(getVertex(v) != nil, "Vertex ", v, " is nil...");
          assert(degree(v) > 0, "Vertex has 0 neighbors...");
          forall e in incidence(v) {
            assert(getEdge(e) != nil, "Edge ", e, " is nil...");
            assert(degree(e) > 0, "Edge has 0 neighbors...");

            var isValid : bool;
            for vv in incidence(e) {
              if vv == v {
                isValid = true;
                break;
              }
            }

            assert(isValid, "Vertex ", v, " has neighbor ", e, " that violates dual property...");
          }
        }

        forall e in getEdges() {
          assert(getEdge(e) != nil, "Edge ", e, " is nil...");
          assert(degree(e) > 0, "Edge has 0 neighbors...");
          forall v in incidence(e) {
            assert(getVertex(v) != nil, "Vertex ", v, " is nil...");
            assert(degree(v) > 0, "Vertex has 0 neighbors...");

            var isValid : bool;
            for ee in incidence(v) {
              if ee == e {
                isValid = true;
                break;
              }
            }

            assert(isValid, "Edge ", e, " has neighbor ", v, " that violates dual property...");
          }
        }
      }

      return (vDupeHistogram, eDupeHistogram);
    }

    /* 
      Removes components in the hypergraph where a hyperedge cannot 'walk' to
      another hyperedge; that is a hyperedge that is isolated from all other
      hyperedges. Returns the number of isolated components.
    */
    proc removeIsolatedComponents() : int {
      // Enforce on Locale 0 (presumed master locale...)
      if here != Locales[0] {
        // Cannot jump and return as return type is inferred by compiler.
        halt("Remove Isolated Components must be performed on master locale #0");
      }

      // Pass 1: Remove isolated components
      writeln("Removing isolated components...");
      var numIsolatedComponents : int;    
      {
        forall e in _edgesDomain with (+ reduce numIsolatedComponents) {
          var n = getEdge(e).degree;
          assert(n > 0, e, " has no neighbors... n=", n);
          if n == 1 {
            var v = getEdge(e).incident[0];

            assert(getVertex(v) != nil, "A neighbor of ", e, " has an invalid reference ", v);
            var nn = getVertex(v).degree;
            assert(nn > 0, v, " has no neighbors... nn=", nn);
            if nn == 1 {
              if _ePropMap.isInitialized then _ePropMap.setProperty(_edges[e].property, -1);
              delete _edges[e];
              _edges[e] = nil;
              
              if _vPropMap.isInitialized then _vPropMap.setProperty(_vertices[v].property, -1);
              delete _vertices[v];
              _vertices[v] = nil;
              
              numIsolatedComponents += 1;
            }
          }
        }
      }

      const __verticesDomain = _verticesDomain;
      const __edgesDomain = _edgesDomain;
      var vertexMappings : [__verticesDomain] int = -1;
      var edgeMappings : [__edgesDomain] int = -1;
      
      writeln("Moving into temporary array...");
      // Move current array into auxiliary...
      const oldVerticesDom = this._verticesDomain;
      const oldEdgesDom = this._edgesDomain;
      var oldVertices : [oldVerticesDom] unmanaged NodeData(eDescType, _vPropType) = this._vertices;
      var oldEdges : [oldEdgesDom] unmanaged NodeData(vDescType, _ePropType) = this._edges;
      this._verticesDomain = {0..#(oldVerticesDom.size - numIsolatedComponents)};
      this._edgesDomain = {0..#(oldEdgesDom.size - numIsolatedComponents)};

      
      // Pass 2: Shift down non-nil spots...
      writeln("Shifting down NodeData...");
      {
        writeln("Shifting down NodeData for Vertices...");
        var idx : atomic int;
        forall v in oldVerticesDom {
          if oldVertices[v] != nil {
            var ix = idx.fetchAdd(1);
            
            // If the locations in the old and new array are the same, we just move it over
            if oldVertices[v].locale == _vertices[ix].locale {
              _vertices[ix] = oldVertices[v];
            } 
            // If the locations are different, we make a copy of the NodeData so that it is local
            // to the new locale.
            else on _vertices[ix] {
              _vertices[ix] = new unmanaged NodeData(oldVertices[v]);
              delete oldVertices[v];
            }

            oldVertices[v] = nil;
            vertexMappings[v] = ix;
          }
        }
        writeln("Shifted down to idx ", idx.read(), " for oldVertices.domain = ", oldVertices.domain);

        writeln("Shifting down NodeData for Edges...");
        idx.write(0);
        forall e in oldEdgesDom {
          if oldEdges[e] != nil {
            var ix = idx.fetchAdd(1);
            
            if oldEdges[e].locale == _edges[ix].locale {
              _edges[ix] = oldEdges[e];
            } else on _edges[ix] {
              _edges[ix] = new unmanaged NodeData(oldEdges[e]);
              delete oldEdges[e];
            }
            
            oldEdges[e] = nil;
            edgeMappings[e] = ix;
          }
        }
        writeln("Shifted down to idx ", idx.read(), " for oldEdges.domain = ", oldEdges.domain);
      }

      writeln("Redirecting references...");
      // Pass 3: Redirect references to shifted vertices and edges to new mappings
      {
        writeln("Redirecting references for Vertices...");
        forall v in _vertices {
          assert(v != nil, "Vertex is nil... Did not appropriately shift down data...", _verticesDomain);
          for e in v {
            e = edgeMappings[e];
          }
        }

        writeln("Redirecting references for Edges...");
        forall e in _edges {
          assert(e != nil, "Edge is nil... Did not appropriately shift down data...", _edgesDomain);
          for v in e {
            v = vertexMappings[v];
          }
        }
      }

      if _vPropMap.isInitialized {
        writeln("Updating PropertyMap...");
        // Pass 4: Update PropertyMap
        {
          writeln("Updating PropertyMap for Vertices...");
          forall vIdx in _vPropMap.values {
            if vIdx != -1 then vIdx = vertexMappings[vIdx]; 
          }

          writeln("Updating PropertyMap for Edges...");
          for eIdx in _ePropMap.values {
            if eIdx != -1 then eIdx = edgeMappings[eIdx];
          }
        }
      }

      if Debug.ALHG_DEBUG {
        forall v in getVertices() {
          assert(getVertex(v) != nil, "Vertex ", v, " is nil...");
          assert(degree(v) > 0, "Vertex has 0 neighbors...");
          forall e in incidence(v) {
            assert(getEdge(e) != nil, "Edge ", e, " is nil...");
            assert(degree(e) > 0, "Edge has 0 neighbors...");

            var isValid : bool;
            for vv in incidence(e) {
              if vv == v {
                isValid = true;
                break;
              }
            }

            assert(isValid, "Vertex ", v, " has neighbor ", e, " that violates dual property...");
          }
        }

        forall e in getEdges() {
          assert(getEdge(e) != nil, "Edge ", e, " is nil...");
          assert(degree(e) > 0, "Edge has 0 neighbors...");
          forall v in incidence(e) {
            assert(getVertex(v) != nil, "Vertex ", v, " is nil...");
            assert(degree(v) > 0, "Vertex has 0 neighbors...");

            var isValid : bool;
            for ee in incidence(v) {
              if ee == e {
                isValid = true;
                break;
              }
            }

            assert(isValid, "Edge ", e, " has neighbor ", v, " that violates dual property...");
          }
        }
      }

      return numIsolatedComponents;
    }

    iter getToplexes(param tag : iterKind) : eDescType where tag == iterKind.standalone  {
      forall e in getEdges() {
        var isToplex = true;
        for ee in getEdges() {
          if ee != e && !isConnected(e, ee, s=1) {
            isToplex = false;
            break;
          }
        }
        if isToplex then yield e;
      }
    }
    
    /*
      Check if we can s-walk from a source vertex to sink vertex.

      :arg v1: Source vertex.
      :arg v2: Sink vertex.
    */
    proc isConnected(v1 : vDescType, v2 : vDescType, s) {
      return getVertex(v1).canWalk(getVertex(v2), s);
    }

    /*
      Check if we can s-walk from a source edge to sink edge.

      :arg e1: Source edge.
      :arg e2: Sink edge.
    */
    proc isConnected(e1 : eDescType, e2 : eDescType, s) {
      return getEdge(e1).canWalk(getEdge(e2), s);
    }
    
    /*
      Obtains the sum of all degrees of all vertices.
    */
    proc getInclusions() : int return + reduce getVertexDegrees();


    /*
        Warning: If you call these inside of the `AdjListHyperGraphImpl`,
        there will not be any privatization, hence you _need_ to call
        getPrivatizedInstance; one easy way to do this is to do something
        like 'with (var _this = getPrivatizedInstance())' so that its only
        obtained once per task per locale.
    */
    
    /*
      Yields all edges in the graph.
    */
    pragma "fn returns iterator"
    proc getEdges(param tag : iterKind) where tag == iterKind.leader {
      return _toLeader(edgesDomain);
    }

    pragma "fn returns iterator"
    proc getEdges(param tag : iterKind, followThis) where tag == iterKind.follower {
      return _toFollower(edgesDomain, followThis);
    }
    
    iter getEdges(param tag : iterKind) where tag == iterKind.standalone {
      forall e in edgesDomain do yield toEdge(e);
    }

    iter getEdges() {
      for e in edgesDomain do yield toEdge(e);
    }

    /*
      Yields all vertices in the graph.
    */
    iter getVertices(param tag : iterKind) where tag == iterKind.standalone {
      forall v in verticesDomain do yield toVertex(v);
    }

    pragma "fn returns iterator"
    proc getVertices(param tag : iterKind) where tag == iterKind.leader {
      return _toLeader(verticesDomain);
    }

    pragma "fn returns iterator"
    proc getVertices(param tag : iterKind, followThis) where tag == iterKind.follower {
      return _toFollower(verticesDomain, followThis);
    }

    iter getVertices() {
      for v in verticesDomain do yield toVertex(v);
    }

    pragma "no doc"
    // Note: this gets called on by a single task...
    // TODO: Need to send back a status saying buffer can be reused
    // but is currently being processed remotely (maybe have a counter
    // determining how many tasks are still processing the buffer), so
    // that user knows when all operations have finished/termination detection.
    inline proc emptyBuffer(buffer : unmanaged Buffer, loc : locale) {
      on loc {
        var buf = buffer.getArray();
        buffer.done();
        var localThis = getPrivatizedInstance();
        local do forall (srcId, destId, srcType) in buf {
          select srcType {
            when InclusionType.Vertex {
              if !localThis.verticesDomain.contains(srcId) {
                halt("Vertex out of bounds on locale #", loc.id, ", domain = ", localThis.verticesDomain);
              }
              ref v = localThis.getVertex(srcId);
              if v.locale != here then halt("Expected ", v.locale, ", but got ", here, ", domain = ", localThis.verticesDomain.localSubdomain(), ", with ", (srcId, destId, srcType));
              v.addIncidence(localThis.toEdge(destId), true);
            }
            when InclusionType.Edge {
              if !localThis.edgesDomain.contains(srcId) {
                halt("Edge out of bounds on locale #", loc.id, ", domain = ", localThis.edgesDomain);
              }
              ref e = localThis.getEdge(srcId);
              if e.locale != here then halt("Expected ", e.locale, ", but got ", here, ", domain = ", localThis.edgesDomain.localSubdomain(), ", with ", (srcId, destId, srcType));
              e.addIncidence(localThis.toVertex(destId), true);
            }
          }
        }
      }
    }
  
    /*
      Flush all aggregation buffers.
    */
    proc flushBuffers() {
      forall (buf, loc) in _destBuffer.flushGlobal() {
        emptyBuffer(buf, loc);
      }
    }


    pragma "no doc" 
    // Resize the edges array
    // This is not parallel safe AFAIK.
    // No checks are performed, and the number of edges can be increased or decreased
    proc resizeEdges(size) {
      edges.setIndices({0..(size-1)});
    }

    pragma "no doc"
    // Resize the vertices array
    // This is not parallel safe AFAIK.
    // No checks are performed, and the number of vertices can be increased or decreased
    proc resizeVertices(size) {
      vertices.setIndices({0..(size-1)});
    }
  
    /*
      Activate automatic aggregation where all calls to `addInclusion` will be aggregated.
    */
    proc startAggregation() {
      // Must copy on stack to utilize remote-value forwarding
      const _pid = pid;
      // Privatization: Set this flag across all locales.
      // No Privatization: Set this flag only for this locale.
      coforall loc in Locales do on loc {
        var _this = chpl_getPrivatizedCopy(this.type, _pid);
        _this._useAggregation = true;
      }
    }

    /*
      Ceases the implicit aggregation of all 'addInclusion' calls. Explicit calls to
      'addInclusionBuffered' will still be aggregated.
    */
    proc stopAggregation() {
      // Must copy on stack to utilize remote-value forwarding
      const _pid = pid;
      coforall loc in Locales do on loc {
        var _this = chpl_getPrivatizedCopy(this.type, _pid);
        _this._useAggregation = false;
      }
    }
  
    /*
      Explicitly aggregate the vertex and element.
      
      :arg vDesc: Vertex.
      :arg eDesc: Edge.
    */
    proc addInclusionBuffered(vDesc : vDescType, eDesc : eDescType) {
      // Forward to normal 'addInclusion' if aggregation is disabled or if not privatized
      // We don't aggregate when not privatized as there is no other locale to send to.
      if AdjListHyperGraphDisableAggregation {
        addInclusion(vDesc, eDesc);
        return;
      }
      
      // Push on local buffers to send later...
      var vLoc = verticesDomain.dist.idxToLocale(vDesc.id);
      var eLoc = edgesDomain.dist.idxToLocale(eDesc.id);
      
      if vLoc == here {
        getVertex(vDesc).addIncidence(eDesc, true);
      } else {
        var vBuf = _destBuffer.aggregate((vDesc.id, eDesc.id, InclusionType.Vertex), vLoc);
        if vBuf != nil {
          begin emptyBuffer(vBuf, vLoc);
        }
      }

      if eLoc == here {
        getEdge(eDesc).addIncidence(vDesc, true);
      } else {
        var eBuf = _destBuffer.aggregate((eDesc.id, vDesc.id, InclusionType.Edge), eLoc);
        if eBuf != nil {
          begin emptyBuffer(eBuf, eLoc);
        }
      }
    }
    
    inline proc addInclusionBuffered(v : vIndexType, e : eIndexType) {
      const vDesc = toVertex(v);
      const eDesc = toEdge(e);
      addInclusionBuffered(vDesc, eDesc);
    }

    inline proc addInclusionBuffered(vDesc : vDescType, e : eIndexType) {
      const eDesc = toEdge(e);
      addInclusionBuffered(vDesc, eDesc);
    }

    inline proc addInclusionBuffered(v : vIndexType, eDesc : eDescType) {
      const vDesc = toVertex(v);
      addInclusionBuffered(vDesc, eDesc);
    }
    
    pragma "no doc"
    inline proc addInclusionBuffered(v, e) {
      Debug.badArgs((v, e), ((vIndexType, eIndexType), (vDescType, eDescType), (vIndexType, eDescType), (vDescType, eIndexType)));
    }
    
    /*
      Adds 'e' as a neighbor of 'v' and 'v' as a neighbor of 'e'.
      If aggregation is enabled via 'startAggregation', this will 
      forward to the aggregated version, 'addInclusionBuffered'.

      :arg vDesc: Vertex.
      :arg eDesc: Edge.
    */
    inline proc addInclusion(vDesc : vDescType, eDesc : eDescType) {
      if !AdjListHyperGraphDisableAggregation && useAggregation {
        addInclusionBuffered(vDesc, eDesc);
        return;
      }
      
      getVertex(vDesc).addIncidence(eDesc, true);
      getEdge(eDesc).addIncidence(vDesc, true);
    }
    
    inline proc addInclusion(v : vIndexType, e : eIndexType) {
      const vDesc = toVertex(v);
      const eDesc = toEdge(e);
      addInclusion(vDesc, eDesc);
    }

    inline proc addInclusion(vDesc : vDescType, e : eIndexType) {
      const eDesc = toEdge(e);
      addInclusion(vDesc, eDesc);
    }

    inline proc addInclusion(v : vIndexType, eDesc : eDescType) {
      const vDesc = toVertex(v);
      addInclusion(vDesc, eDesc);
    }
    
    pragma "no doc"
    inline proc addInclusion(v, e) {
      Debug.badArgs((v, e), ((vIndexType, eIndexType), (vDescType, eDescType), (vIndexType, eDescType), (vDescType, eIndexType)));
    }

    
    /*
      Check if the vertex 'v' is incident in edge 'e'.
      
      :arg v: Vertex.
      :arg e: Edge.
    */ 
    proc hasInclusion(v : vIndexType, e : eIndexType) {
      const vDesc = toVertex(v);
      const eDesc = toEdge(e);

      return getVertex(vDesc).hasNeighbor(eDesc);
    }
    
    proc hasInclusion(vDesc : vDescType, e : eIndexType) {
      const eDesc = toEdge(e);
      return getVertex(vDesc).hasNeighbor(eDesc);
    }

    proc hasInclusion(v : vIndexType, eDesc : eDescType) {
      const vDesc = toVertex(v);
      return getVertex(vDesc).hasNeighbor(eDesc);
    }

    proc hasInclusion(vDesc : vDescType, eDesc : eDescType) {
      return getVertex(vDesc).hasNeighbor(eDesc);     
    }

    pragma "no doc"
    proc hasInclusion(v, e) {
      Debug.badArgs((v, e), ((vIndexType, eIndexType), (vDescType, eDescType), (vIndexType, eDescType), (vDescType, eIndexType)));
    }

    /*
      Remove duplicates from incidence list both vertices and edges. Useful to invoke after graph generation.
    */
    proc removeDuplicates() {
        var (vertexNeighborsRemoved, edgeNeighborsRemoved) : 2 * int;
        forall v in getVertices() with (+ reduce vertexNeighborsRemoved, var _this = getPrivatizedInstance()) {
            vertexNeighborsRemoved += _this.getVertex(v).makeDistinct();
        }
        forall e in getEdges() with (+ reduce edgeNeighborsRemoved, var _this = getPrivatizedInstance()) {
            edgeNeighborsRemoved += _this.getEdge(e).makeDistinct();
        }
        return (vertexNeighborsRemoved, edgeNeighborsRemoved);
    }

    /*
      Obtains the edge descriptor for the integral edge id. If 'boundsChecking' is
      enabled, we verify that the id is a valid index (I.E compiling without --fast).
    
      :arg id: Integer identifier for an edge.
    */
    inline proc toEdge(id : integral) {
      if boundsChecking && !edgesDomain.contains(id : eIndexType) {
        halt(id, " is out of range, expected within ", edgesDomain);
      }
      return (id : eIndexType) : eDescType;
    }

    inline proc toEdge(desc : eDescType) {
      return desc;
    }

    // Bad argument...
    pragma "no doc"
    inline proc toEdge(other) param {
      Debug.badArgs(other, (eIndexType, eDescType));
    }

    /*
      Obtains the vertex descriptor for the integral vertex id. If 'boundsChecking' is
      enabled, we verify that the id is a valid index (I.E compiling without --fast).
    
      :arg id: Integer identifier for a vertex.
    */
    inline proc toVertex(id : integral) {
      if boundsChecking && !verticesDomain.contains(id : vIndexType) {
        halt(id, " is out of range, expected within ", verticesDomain);
      }
      return (id : vIndexType) : vDescType;
    }

    inline proc toVertex(desc : vDescType) {
      return desc;
    }

    // Bad argument...
    pragma "no doc"
    inline proc toVertex(other) {
      Debug.badArgs(other, (vIndexType, vDescType));
    }
    
    /*
      Returns vertex degree sequence as array.
    */
    proc getVertexDegrees() {
      const degreeDom = verticesDomain;
      var degreeArr : [degreeDom] int(64);
      // Must be on locale 0 or else we get issues of accessing
      // remote data in local block. Chapel arrays somehow lift
      // this issue for normal array access. Need further investigation...
      on Locales[0] {
        var _this = getPrivatizedInstance();
        forall (degree, v) in zip(degreeArr, _this._vertices) {
          degree = v.degree;
        }
      }
      return degreeArr;
    }

    /*
      Returns hyperedge cardinality sequence as array.
    */
    proc getEdgeDegrees() {
      const degreeDom = edgesDomain;
      var degreeArr : [degreeDom] int(64);
      on Locales[0] {
        var _this = getPrivatizedInstance();
        forall (degree, e) in zip(degreeArr, _this._edges) {
          degree = e.degree;
        }
      }
      return degreeArr;
    }
    
    /*
      Obtain the locale that the given vertex is allocated on
    
      :arg v: Vertex.
    */
    inline proc getLocale(v : vDescType) : locale {
      return verticesDist.idxToLocale(v.id);
    }
    
    /*
      Obtain the locale that the given edge is allocated on

      :arg e: Edge.
    */
    inline proc getLocale(e : eDescType) : locale {
      return edgesDist.idxToLocale(e.id);
    }
    
    pragma "no doc"
    inline proc getLocale(other) {
      Debug.badArgs(other, (vDescType, eDescType));
    }
    
    /*
      Obtain the size of the intersection of both hyperedges.

      :arg e1: Hyperedge.
      :arg e2: Hyperedge.
    */
    proc intersectionSize(e1 : eDescType, e2 : eDescType) {
      return getEdge(e1).intersectionSize(getEdge(e2));
    }
    
    /*
      Obtain the size of the intersection of both vertices.

      :arg v1: Vertex.
      :arg v2: Vertex.
    */
    proc intersectionSize(v1 : vDescType, v2 : vDescType) {
      return getVertex(v1).intersectionSize(getVertex(v2));
    }

    /*
      Yield edges that are in the intersection of both vertices.
      
      :arg e1: Hyperedge.
      :arg e2: Hyperedge.
    */
    iter intersection(e1 : eDescType, e2 : eDescType) {
      for n in getEdge(e1).neighborIntersection(getEdge(e2)) do yield n; 
    }

    iter intersection(e1 : eDescType, e2 : eDescType, param tag : iterKind) where tag == iterKind.standalone {
      for n in getEdge(e1).neighborIntersection(getEdge(e2)) do yield n; 
    }

    iter intersection(v1 : vDescType, v2 : vDescType) {
      for n in getVertex(v1).neighborIntersection(getVertex(v2)) do yield n;
    }

    iter intersection(v1 : vDescType, v2 : vDescType, param tag : iterKind) where tag == iterKind.standalone {
      forall n in getVertex(v1).neighborIntersection(getVertex(v2)) do yield n;
    }
    
    pragma "no doc"
    inline proc _snapshot(v : vDescType) {
      ref vertex = getVertex(v);
      vertex.lock.acquire();
      var snapshot = vertex.incident[0..#vertex.degree];
      vertex.lock.release();

      return snapshot;
    }

    pragma "no doc"
    inline proc _snapshot(e : eDescType) {
      ref edge = getEdge(e);
      edge.lock.acquire();
      var snapshotDom = {0..#edge.degree};
      var snapshot : [snapshotDom] int = edge.incident[0..#edge.degree];
      edge.lock.release();

      return snapshot;
    }
    
    /*
      Obtains the vertices incident in this hyperedge.

      :arg e: Hyperedge descriptor.
    */
    iter incidence(e : eDescType) {
      for v in _snapshot(e) do yield toVertex(v);
    }

    iter incidence(e : eDescType, param tag : iterKind) ref where tag == iterKind.standalone {
      forall v in _snapshot(e) do yield toVertex(v);
    }
    
    /*
      Obtains the hyperedges this vertex is incident in.

      :arg v: Vertex descriptor.
    */
    iter incidence(v : vDescType) ref {
      for e in _snapshot(v) do yield toEdge(e);
    }

    iter incidence(v : vDescType, param tag : iterKind) ref where tag == iterKind.standalone {
      forall e in _snapshot(v) do yield toEdge(e);
    }

    pragma "no doc"
    iter incidence(arg) {
      Debug.badArgs(arg, (vDescType, eDescType));
    }

    pragma "no doc"
    iter incidence(arg, param tag : iterKind) where tag == iterKind.standalone {
      Debug.badArgs(arg, (vDescType, eDescType));
    }


    /*
      Iterate through pairs vertices along with the edges they are incident in.
    */
    iter these() : (vDescType, eDescType) {
      for v in getVertices() {
        for e in incidence(v) {
          yield (v, e);
        }
      }
    }

    iter these(param tag : iterKind) : (vDescType, eDescType) where tag == iterKind.standalone {
      forall v in getVertices() {
        for e in incidence(v) {
          yield (v, e);
        }
      }
    }
  
    /*
       Return the incidence list associated with a vertex.
      
       :arg v: Vertex descriptor.
    */
    proc this(v : vDescType) {
      return _snapshot(v);
    }
    
    /*
       Return the incidence list associated with a hyperedge.
      
       :arg e: Hyperedge descriptor.
    */
    proc this(e : eDescType) {
      return _snapshot(e);
    }
  } // class AdjListHyperGraph
  
  /*
    Invokes 'addInclusion'
  */
  inline proc +=(graph : AdjListHyperGraph, other) {
    graph._value += other;
  }

  inline proc +=(graph : unmanaged AdjListHyperGraphImpl, (v,e) : (graph.vDescType, graph.eDescType)) {
    graph.addInclusion(v,e);
  }
  
  inline proc +=(graph : unmanaged AdjListHyperGraphImpl, (e,v) : (graph.eDescType, graph.vDescType)) {
    graph.addInclusion(v,e);
  }

  pragma "no doc"
  inline proc +=(graph : unmanaged AdjListHyperGraphImpl, other) {
    Debug.badArgs(other, (graph.vDescType, graph.eDescType));
  }

  pragma "no doc"
  module Debug {
    // Provides a nice error message for when user provides invalid type.
    proc badArgs(bad, type good, param errorDepth = 2) param {
      compilerError("Expected argument of type to be in ", good : string, " but received argument of type ", bad.type : string, errorDepth);
    }

    config param ALHG_DEBUG : bool;

    // Determines whether or not we profile for contention...
    config param ALHG_PROFILE_CONTENTION : bool;
    // L.J: Keeps track of amount of *potential* contended accesses. It is not absolute
    // as we check to see if the lock is held prior to attempting to acquire it.
    var contentionCnt : atomic int;

    inline proc contentionCheck(ref lock : atomic bool) where ALHG_PROFILE_CONTENTION {
      if lock.read() {
        contentionCnt.fetchAdd(1);
      }
    }

    inline proc contentionCheck(ref lock : atomic bool) where !ALHG_PROFILE_CONTENTION {
      // NOP
    }
  }
}
