/*Boundary matrix computation with a toy example.*/
use CHGL; // Includes all core and utility components of CHGL
use Time; // For Timer
use Set;
use Map;
use List;
use Sort;
use Search;

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
    if !_vtxSubsetSet.contains(verticesStr) { // TODO: redundant?
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
  compilerWarning(verticesInEdge.type :string );
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
  proc findCellIndex(s :string) {
    for k in A {
      
    }
  }
}

var numBins = kCellMap.size - 1;
var kCellsArrayMap : [0..numBins] owned kCellsArray?;
var kCellKeys = kCellMap.keysToArray();
sort(kCellKeys);

// Empty record serves as comparator
record Comparator { }
// compare method defines how 2 elements are compared
proc Comparator.compare(a :string, b :string) : int {
  var retVal : int = 0;
  if (b == "") {
    writeln("a: " + a : string + " b: " + b : string);
    retVal = -1;
    return retVal;
  }
  var   aa =  a.split(" ") : int;
  var   bb = b.split(" ") : int;
  var done : bool = false;
  var ndone : bool = false;
  for i in 1..#aa.size {
    for j in i..#bb.size {
      if (aa[i] == bb[j]) {
	break;
      }
      if (aa[i] < bb[j]) {
	retVal = -1; done = true; break;
      }
      if (aa[i] > bb[j]) {
	retVal = 1; done = true; break;
      }
    }
    if (done) {break;}
  }
  return retVal;
}
var absComparator: Comparator;


// sort(Array, comparator=absComparator);
/*TODO: change the following loop as follows:*/
/*forall k in 0..K {
  kCellsArrayMap[k] = new owned kCellsArray(k + 1);
  kCellsArrayMap[k].A = kCellMap[k + 1].toArray(); 
  sort(kCellsArrayMap[k].A, comparator=absComparator);
}*/

writeln("%%%%%%%%%%%%%");
// Leader-follower iterator
// Create the new KcellMaps for convenience of sorting
for (_kCellsArray, kCellKey) in zip(kCellsArrayMap, kCellKeys) {
  writeln("listsize: " + kCellMap[kCellKey].size : string);
  _kCellsArray = new owned kCellsArray(kCellMap[kCellKey].size);
  _kCellsArray.A = kCellMap[kCellKey].toArray(); 
  // compilerWarning(kCellMap[kCellKey].toArray().type : string);
  sort(_kCellsArray.A, comparator=absComparator);
  /* for c in kCellMap[kCellKey].toArray() { */
  /*   writeln(c); */
  /*   compilerWarning(c.type: string); */
  /* } */
}
writeln("%%%%%%%%%%%%%");

// TODO: change the following:
/*
for (_kCellsArray, idx) in (kCellsArrayMap, 1..K) {
  writeln((_kCellsArray.A, idx) : string);
}
*/
writeln("Printing after sorting");
writeln("^^^^^^^^^^^^^^^^^^^^^^^");
/* for (_kCellsArray, idx) in zip(kCellsArrayMap, 1..numBins) { */
/*   writeln((_kCellsArray.A, idx) : string); */
/* } */
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


var vs = new set(string);

iter processVtxSubset2(vtxSubset) {
  for i in 1..#vtxSubset.size {
    var tmp : [1..#vtxSubset.size - 1] int;
    tmp[1..i - 1] = vtxSubset[1..i - 1];
    tmp[i..] = vtxSubset[i + 1..];
    yield tmp;
  }
}

/* Generate the permutation */
proc doProcessVertices2 (verticesSet) {
  if (verticesSet.size == 0) {
    return;
  } else if (verticesSet.size == 1) {
    var verticesStr = stringify(verticesSet);
    if !vs.contains(verticesStr) {
      vs.add(verticesStr);
    }
  } else {
    var verticesStr = stringify(verticesSet);
    if !vs.contains(verticesStr) {
      vs.add(verticesStr);
      for _vtxSubset in processVtxSubset2(verticesSet) {
      	doProcessVertices2(_vtxSubset);
      }
    }
  }
}


writeln("####");
// Compute values for each entries in each of the boundary map
for (boundaryMap, dimension_k_1, dimension_k) in zip(boundaryMaps, 0.., 1..) {
  var arrayOfKCells  = kCellsArrayMap[dimension_k].A; // Arrays of strings, each string being 1 kcell
  var arrayOfK_1Cells = kCellsArrayMap[dimension_k_1].A;
  compilerWarning(arrayOfK_1Cells.type : string);
  writeln("$$$$$$$$$$$");
  writeln(arrayOfKCells);
  writeln(arrayOfK_1Cells);
  writeln("$$$$$$$$$$$");
  var i : int = 0;
  var j : int = 0;
  for SkCell in arrayOfKCells { // iterate through all the k-cells
    i = i + 1;
    /* Generate permutation of the current k-Cell*/
    // compilerWarning(SkCell.type : string);
    var kCell = SkCell.split(" ") : int;
    // compilerWarning(kCell.type : string);
    writeln("#kcell: " + kCell :string);
    /* writeln("Combinations generated ": string); */
    for sc in processVtxSubset(kCell) {
      compilerWarning(sc.type : string);
      writeln(sc);
      var st = stringify(sc);
      j = 0;
      for Sk_1Cell in arrayOfK_1Cells {
	j = j + 1;
	if (st == Sk_1Cell) {
	  writeln(st :string + "matches");
	  boundaryMap.matrix[j, i] = 1;
	  break;
	}
      }
    }
  }
  writeln("$$$$$$$$$$$");
}

proc printBoundaryMap(boundaryMap) {
  var row : int = boundaryMap.matrix.domain.high(1);
  var col : int = boundaryMap.matrix.domain.high(2);
  for i in 1..row {
    for j in 1..col {
      write(boundaryMap.matrix[i, j] : string + " ");
    }
    writeln();
  }
}

for (boundaryMap, dimension_k_1, dimension_k) in zip(boundaryMaps, 0.., 1..) {
  writeln("Printing boundary map for: " : string + dimension_k_1 : string + " " :string + dimension_k : string);
  printBoundaryMap(boundaryMap);
}
