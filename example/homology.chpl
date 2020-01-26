use CHGL; // Includes all core and utility components of CHGL
use Time; // For Timer
use Set;
use Map;
use List;
use Sort;
use Search;
/*
    Part 1: Global-View Distributed Data Structures
*/
// Question: How do we create a toy hypergraph?
// Answer: Generate it!
/* config const numVertices = 4; */
/* config const numEdges = 10; */
/* config const edgeProbability = 1; */
/* var hypergraph = new AdjListHyperGraph(numVertices, numEdges, new unmanaged Cyclic(startIdx=0)); */
/* var timer = new Timer(); */
/* timer.start(); */
/* generateErdosRenyi(hypergraph, edgeProbability); */
/* timer.stop(); */
/* writeln("Generated ErdosRenyi with |V|=", numVertices,  */
/*     ", |E|=", numEdges, ", P_E=", edgeProbability, " in ", timer.elapsed(), " seconds"); */


/* writeln("Removing duplicates: ", hypergraph.removeDuplicates()); */
/* hypergraph.removeDuplicates(); */

var hypergraph = new AdjListHyperGraph(4, 1, new unmanaged Cyclic(startIdx=0));
for v in hypergraph.getVertices() do hypergraph.addInclusion(v, 0);


//  writeln(e : string + " vertices:" + vertices :string);
//  writeln("-----");
  /* for currentsize in 1..#vertices.size by -1 { */
  /*   writeln("Strings: "); */

//    writeln(elmInSubset : string);

// var vertices = graph.incidence(graph.toEdge(eIdx));

var _vtxSubsetSet = new set(string);

iter processVtxSubset(vtxSubset) {
  for i in 1..#vtxSubset.size {
    var tmp : [1..#vtxSubset.size - 1] int;
    tmp[1..i - 1] = vtxSubset[1..i - 1];
    tmp[i..] = vtxSubset[i + 1..];
    yield tmp;
  }
}

/* Generate the permutation */
proc doProcessVertices (verticesSet) {
  if (verticesSet.size == 0) {
    return;
  } else if (verticesSet.size == 1) {
    var verticesStr = stringify(verticesSet);
    if !_vtxSubsetSet.contains(verticesStr) {
      _vtxSubsetSet.add(verticesStr);
    }
  } else {
    var verticesStr = stringify(verticesSet);
    if !_vtxSubsetSet.contains(verticesStr) {
      _vtxSubsetSet.add(verticesStr);
      for _vtxSubset in processVtxSubset(verticesSet) {
      	doProcessVertices(_vtxSubset);
      }
    }
  }
}

/*For each of the hyperedge, do the permutation of all the vertices.*/
for e in hypergraph.getEdges() {
  var vertices = hypergraph.incidence(e); // ABCD
  // writeln(vertices.domain);
  ref tmp = vertices[1..#vertices.size];
  var verticesInEdge : [1..#vertices.size] int;
  verticesInEdge[1..#vertices.size] = tmp.id; // ABCD vertices.low
  doProcessVertices(verticesInEdge);
}

writeln("Printing all generated combination");
/*Verify the set by printing*/
var setContent = _vtxSubsetSet.toArray();
for c in setContent do
  writeln(c);

writeln("-----");
var _sz = 0;
writeln("Printing bins");
/*bin k-cells, with key as the length of the list and value is a list with all the k-cells*/
var kCellMap = new map(int, list(string, true));
for vtxSet in _vtxSubsetSet {
  //var _vtxSet = vtxSet.split(" ");
  var sz = + reduce [ch in vtxSet] ch == ' ';
  writeln(sz : string + " " + vtxSet : string);
  kCellMap[sz].append(vtxSet);
  _sz = sz;
}

class kCellsArray{
  var numKCells : int;
  var D = {1..numKCells};
  var A : [D] string;
  proc init(_N: int) {
    numKCells = _N;
  }
}

var numBins = kCellMap.size - 1;
var kCellsArrayMap : [0..numBins] owned kCellsArray?;
var kCellKeys = kCellMap.keysToArray();
sort(kCellKeys);

// Empty record serves as comparator
record Comparator { }
// compare method defines how 2 elements are compared
// Simplified comparator since we know that the strings are of the same size
proc Comparator.compare(a :string, b :string) : int {
  var retVal : int = 0;
  for (c1, c2) in zip (a , b) {
    if (c1 == c2) {continue;}
    if (c1 < c2) {retVal = -1; break;}
    else {retVal = 1; break;}
  }
  return retVal;
}

var absComparator: Comparator;


// sort(Array, comparator=absComparator);

writeln("%%%%%%%%%%%%%");
// Leader-follower iterator
// Create the new KcellMaps for convenience of sorting
for (_kCellsArray, kCellKey) in zip(kCellsArrayMap, kCellKeys) {
  writeln("listsize: " + kCellMap[kCellKey].size : string);
  _kCellsArray = new owned kCellsArray(kCellMap[kCellKey].size);
  _kCellsArray.A = kCellMap[kCellKey].toArray(); 
  compilerWarning(kCellMap[kCellKey].toArray().type : string);
  sort(_kCellsArray.A, comparator=absComparator);
  /* for c in kCellMap[kCellKey].toArray() { */
  /*   writeln(c); */
  /*   compilerWarning(c.type: string); */
  /* } */
}
writeln("%%%%%%%%%%%%%");

writeln("Printing after sorting");
writeln("^^^^^^^^^^^^^^^^^^^^^^^");
for _kCellsArray in kCellsArrayMap {
  writeln(_kCellsArray.A : string);
}
writeln("^^^^^^^^^^^^^^^^^^^^^^^");

/*Start of the construction of boundary matrices.*/
class Matrix {
  var N : int;
  var M : int;
  var matrix : [1..N, 1..M] int;
  proc init(_N: int, _M:int) {
    N = _N;
    M = _M;
  }
}

var K = kCellMap.size - 1;
var boundaryMaps : [1..K] owned Matrix?;
var i : int = 1; 

// Leader-follower iterator
// Create the boundary Maps
for (boundaryMap, dimension_k_1, dimension_k) in zip(boundaryMaps, 0.., 1..) {
  writeln("dimensions: " + kCellsArrayMap[dimension_k_1].numKCells: string + " " + kCellsArrayMap[dimension_k].numKCells : string);
  boundaryMap = new owned Matrix(kCellsArrayMap[dimension_k_1].numKCells, kCellsArrayMap[dimension_k].numKCells);
}

/* forall (boundaryMap, dimension_k_1, dimension_k) in zip(boundaryMaps, 0.., 1..) { */
/*   writeln("dimensions: " + kCellMap[dimension_k_1].size: string + " " + kCellMap[dimension_k].size : string); */
/*   boundaryMap = new owned Matrix(kCellMap[dimension_k_1].size, kCellMap[dimension_k].size); */
/* } */


writeln("####");
// Compute values for each entries in each of the boundary map
for (boundaryMap, dimension_k_1, dimension_k) in zip(boundaryMaps, 0.., 1..) {
  var arrayOfKCells  = kCellsArrayMap[dimension_k].A;
  var arrayOfK_1Cells = kCellsArrayMap[dimension_k_1].A;
  writeln("$$$$$$$$$$$");
  writeln(arrayOfKCells);
  writeln(arrayOfK_1Cells);
  writeln("$$$$$$$$$$$");
  for SkCell in arrayOfKCells {
    var kCell = SkCell.split(" ");
    /* for kk in kCell { */
    /*   compilerWarning(kk.type :string); */
    /*    writeln("kk:" + kk :string); */
    /* } */
    /* compilerWarning(kCell.type : string); */
    for Sk_1Cell in arrayOfK_1Cells {
      var k_1Cell = Sk_1Cell.split(" ");
      for kk in k_1Cell {
	var (found, Pos) = binarySearch(kCell, kk, comparator=absComparator);
	if (found) {
	  writeln(kk : string + " was found in: " + kCell);
	}
      }
      writeln("Considering combination: " , kCell : string + " and "  + k_1Cell :string);
      /* var position = kCell.find(k_1Cell); */
      /* if (position != 0) { */
      /* 	writeln(k_1Cell: string + " Occurs at position: " + position : string); */
      /* } */
    }
  }
  writeln("$$$$$$$$$$$");
}



/* forall (_kCellsArray, kCellList) in zip(kCellsArrayMap, kCellMap) { */
/*   // writeln("listsize: " + kCellMap[kCellList].size : string); */
/* } */

// compilerWarning(kCellMap[_sz].type : string);


// for kCell in kCellMap {
  // compilerWarning(kCellMap[kCell].type : string);
  // kCellMap[kCell].sort(comparator=absComparator);
// }

// Verify k-cells
/* for kCell in kCellMap { */

/*   writeln(kCellMap(kCell)); */
/* } */
// writeln("-----");


  /* var sz_a = a.size; */
  /* var sz_b = b.size; */
  /* // var c: string; */
  /* var sz = 0; */
  /* if (sz_a <= sz_b) { */
  /*   sz = sz_a; */
  /*   // c = a; */
  /* } else { */
  /*   // c = b */
  /*   sz = sz_b; */
  /* } */
  /* /\* for l in c { *\/ */
  /* /\*   if  *\/ */
  /* /\* } *\/ */
  /* var i = 0; */
  /* while (i < sz) { */
  /*   if (a[i] == b[i]) {i += 1;}//continue; */
  /*   if (a[i] < b[i]) { */
  /*     // i += 1; */
  /*     return -1; */
  /*   } else { */
  /*     // i += 1; */
  /*     return 1; */
  /*   } */
  /* } */


// Both of the following methods work for allocating the array.
//var boundaryMaps: owned Matrix? = new owned Matrix[1..10];
// var boundaryMaps : [1..K] owned Matrix?;
// var i : int = 1; 
/* for boundaryMap in boundaryMaps { */
/*   var dimension_k_1 = kCellMap[i - 1].size; */
/*   var dimension_k = kCellMap[i].size; */
/*   i += 1; */
/*   writeln("dimensions: " + dimension_k_1: string + " " + dimension_k: string); */
/*   boundaryMap = new owned Matrix(dimension_k_1, dimension_k); */
/* } */


  // var splitlistOfKCells = listOfKCells.split(",");
  // compilerWarning(splitlistOfKCells.type : string);
  // writeln(splitlistOfKCells);
  /* var listOfK_1Cells = kcellMap[dimension_k_1].split(" "); // got all (k-1)-cells */
  /* var lstIndex = 1; */
  /* for column in 1..#boundaryMap.M { */
  /*   var _kcell = listOfKCells(lstIndex); // no way to index with [] operator? */
  /*   for row in 1..#boundaryMap.N { */
  /*     var _k_1Cell = listOfK_1Cells(lstIndex); */
  /*     var position = _kcell.find(_k_1Cell); */
  /*     if (position != 0 ) {//store the location where the match occurs. if the location is odd , store -1, else store 1} */
  /* 	boundaryMap[row, column] = ((position % 2) == 0 ? 1 : -1); */
  /*     } else { */
  /* 	boundaryMap[row, column] = 0; */
  /*     } */
  /*     lstIndex += 1; */
  /* } */

//  compilerWarning(listOfKCells.type : string); // list of strings ["0 1 2", "1 2 3"]
//  writeln(listOfKCells); //.split(" "); // get all k-cells
  /* writeln(kcell); */
  /*   compilerWarning(kcell.type :string); */
  /*   writeln("---->"); */
  
  /*   compilerWarning(sp.type : string); */
  /*   writeln(sp); */
  /*   writeln(sp.size); */
  /*   writeln("---->"); */


// For each k
// Allocate the matrix of size |k-1|X |k|
// Compute the entries of the matrix using the formula:

// 
//     
  /* for subset in processEdge(hypergraph, e) { */
  /*   //  writeln(e : string + "subset of vertices:" + subset : string); */
  /* } */
  // doProcessEdge(e); // Ensure we run every edge in parallel/distributed


/* var newEdgeIdx : atomic int; */
/* forall e in hypergraph.getEdges() { */
/*   for subset in processEdge(e) { */
/*     var subsetStr = stringify(subset); */
/*     // Needs to be atomic... transactional */
/*     if !set.contains(subsetStr) { */
/*       var ix = newEdgeIdx.fetchAdd(1); // New index for this edge... */
/*       set[subsetStr] = ix; */
/*       // Recursively process 'subset' via 'processEdge'... */
/*     } */
/*     // Else we prune by not doing anything */
/*   } */
/* } */

/* var newHypergraph = new AdjListHyperGraph(numVertices, newEdgeIdx.read()); */
/* forall (subsetStr, eIdx) in set { */
/*   var subset = unstringify(subsetStr); */
/*   for x in subset do newHypergraph.addInclusion(x, eIdx); // Aggregated if distributed */
/* } */


/* for e in hypergraph.getEdges() { */
/*   compilerWarning(hypergraph.degree(e).type : string); */
/* } */

/* var degree : int; */
/* forall e in hypergraph.getEdges() with (max reduce degree) { */
/*   degree = max(hypergraph.degree(e), degree); */
/* } */
/* writeln(degree); */

/* forall e in hypergraph.getEdges() { */
/*   compilerWarning(e.type : string); */
/* } */

/* // writeln(max reduce  [e in hypergraph.getEdges()] compilerWarning(e.type : string)); */
/* // writeln(max reduce [e in hypergraph.getEdges()] hypergraph.degree(e)); */
/* writeln([e in hypergraph.getEdges()] hypergraph.degree(e)); */

/* forall e in hypergraph.getEdges() { */
/*   // for v in hypergraph.incidence(e) { */
/*   writeln(e : string + " = " + hypergraph.incidence(e) : string); */
/*     // } */
/* } */



var M : [1..10, 1..10] int;
for (i,j) in M.domain do M[i,j] = i + j;
for s in 1..10 {
  ref M_ = M[.., s..];
  var val, loc = minloc reduce zip(M_, M_.domain);
  writeln("Minimum value for s = ", s, " is ", val, " and location is ", loc);
}

proc IdentityMatrix(n) {
  var A : [1..n, 1..n] int = 1;
  return A;
}

proc swap_rows(M, i, j) { M[i, ..] <=> M[j, ..]; }
proc swap_cols(M, i, j) { M[.., i] <=> M[.., j]; }
proc add_to_row(M,x,k,s) {M[x, ..] += k * M[s, ..]; M[x, ..] = M[x, ..] % 2; }
proc add_to_column(M,x,k,s){M[.., x] += k * M[.., s]; M[.., x] = M[.., x] % 2;}

proc change_sign_row(M) { M[x, ..] = -M[x, ..]; }
proc change_sign_col(M) {M[.., x] = -M[.., x];}

proc is_lone(M,s) {
  return (&& reduce (M[s,s+1..] != 0)) && (&& reduce (M[s+1.., s] != 0));
}

proc get_nextentry(M,s) {
  const val = M[s,s];
  for ((i,j), m) in zip(M.domain, M) {
    if m % val != 0 then return (i,j);
  }
  throw CustomError(..);
}