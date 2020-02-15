/*Example of Boundary matrix computation with a toy example.*/
use CHGL; // Includes all core and utility components of CHGL
use Time; // For Timer
use Set;
use Map;
use List;
use Sort;
use Search;
use HashedDist;
use CyclicDist;

// Empty record serves as comparator
record Comparator { }
// compare method defines how 2 elements are compared
proc Comparator.compare(a : Cell, b : Cell) : int {
	assert(a.size == b.size);
	for (_a, _b) in zip(a,b) {
		if (_a > _b) then return 1;
		else if (_a < _b) then return -1;
	}
	return 0;
}

proc intersection(A : [] ?t, B : [] t) {
	var CD = {0..#min(A.size, B.size)};
	var C : [CD] t;
	var idxA = A.domain.low;
	var idxB = B.domain.low;
	var idxC = 0;
	while idxA <= A.domain.high && idxB <= B.domain.high {
		const a = A[idxA];
		const b = B[idxB];
		if a == b { 
		C[idxC] = a;
		idxC += 1;
		idxA += 1; 
		idxB += 1; 
		}
		else if a > b { 
		idxB += 1;
		} else { 
		idxA += 1;
		}
	}
	CD = {0..#idxC};
	return C;	
}

var absComparator : Comparator();
var hypergraph = new AdjListHyperGraph(4, 1, new unmanaged Cyclic(startIdx=0));
forall v in hypergraph.getVertices() do hypergraph.addInclusion(v, 0);

proc chpl__defaultHash(cell : Cell) {
	var arr = makeArrayFromPtr(cell.vertices : c_void_ptr : c_ptr(int), cell.numVertices : uint(64));
	return chpl__defaultHash(arr);
}

record Cell {  
	var numVertices : int;  
	var vertices : _ddata(int);

	proc init() {}
	proc init(numVertices : int) {   
		this.numVertices = numVertices;    
    	this.vertices = _ddata_allocate(int, numVertices, initElts=false);  
  	}

	  proc init(arr : [?D] int) {
		  init(for a in arr do a);
	  }
	  

	// `var kcell = new Cell(array);`                                                                                                                                                         
	// `var kcell = new Cell(domain);`                                                                                                                                                        
	// `var kcell = new Cell([x in 1..10] x * 2);`                                                                                                                                            
	proc init(iterable : _iteratorRecord) {    
		this.complete();
		var cap : int;    
		for x in iterable {      
			if numVertices >= cap {        
				if cap == 0 {          
					cap = 1;          
					this.vertices = _ddata_allocate(int, cap, initElts=false);        
				} else {          
					var oldCap = cap;          
					cap = cap * 2;          
					var tmp = _ddata_allocate(int, cap, initElts=false);          
					for i in vectorizeOnly(0..#oldCap) do 
						tmp[i] = this.vertices[i];          
					_ddata_free(this.vertices, oldCap);          
					this.vertices = tmp;        
				}      
			}      
			this.vertices[this.numVertices] = x;      
			this.numVertices += 1;    
		}

		// Shrink...
		var tmp = _ddata_allocate(int, this.numVertices, initElts=false);
		for i in vectorizeOnly(0..#numVertices) do tmp[i] = this.vertices[i];
		_ddata_free(this.vertices, cap);
		this.vertices = tmp;  

		var arr = makeArrayFromPtr(this.vertices : c_void_ptr : c_ptr(int), this.numVertices : uint(64));
    	sort(arr);
	}

	proc writeThis(f) {
		f <~> "{";
		for i in 0..#numVertices do f <~> " " <~> this[i] <~> " ";
		f <~> "}";
	}
	iter these() ref {    
		for i in 0..#numVertices do 
			yield vertices[i];  
	}
	proc this(idx : int) ref {    
		return vertices[idx];  
	}

  proc size return this.numVertices;
}

proc ==(c1 : Cell, c2 : Cell) {
	if c1.size != c2.size then return false;
	for (a,b) in zip(c1, c2) {
		if a != b then return false;
	}
	return true;
}

proc >(c1 : Cell, c2 : Cell) {
	if c1.size > c2.size then return true;
	else if c1.size < c2.size then return false;
	for (a,b) in zip(c1, c2) {
		if a > b then return true;
		else if a < b then return false;
	}
	return false;
}

proc <(c1 : Cell, c2 : Cell) {
	if c1.size > c2.size then return false;
	else if c1.size < c2.size then return true;
	for (a,b) in zip(c1, c2) {
		if a > b then return false;
		else if a < b then return true;
	}
	return false;
}

// Takes a kcell (k0, k1, ..., kN) and
// yield combinations \forall i {
//  (k1, k2, ..., kN), ... (k0, k1, ..., ki, ..., kN), (k0, k1, ..., kN-1)
// }
iter splitKCell(cell) {
	for i in 0..#cell.size {
    	var newCell = new Cell(cell.size - 1);
		newCell[0..i - 1] = cell[0..i - 1];
		newCell[i..newCell.size - 1] = cell[i + 1..cell.size - 1];
		yield newCell;
	}
}

// Need to make parallel
/* Generate the permutation */
proc processCell (kcell, cellSet) {
	// If we only have one vertex in this kcell, it is a 0-cell
  // and so we recurse no further, but we do add it to the set...
  if (kcell.size == 1) {
		cellSet.add(kcell);
	} else {
    // PRUNE!!!
		if !cellSet.contains(kcell) {
			cellSet.add(kcell);
			for cell in splitKCell(kcell) {
				processCell(cell, cellSet);
			}
		}
	}
}

/*For each of the hyperedge, do the permutation of all the vertices.*/
var cellSets : [0..#numLocales, 0..#here.maxTaskPar] set(Cell);
// TODO: Use Privatized to cut down communication...
var taskIdCounts : [0..#numLocales] atomic int; 
forall e in hypergraph.getEdges() with (var tid : int = taskIdCounts[here.id].fetchAdd(1)) {
	var vertices = hypergraph.incidence(e); // ABCD
	ref tmp = vertices[1..#vertices.size];
	var verticesInEdge : [1..#vertices.size] int = tmp.id;
 	processCell(new Cell(verticesInEdge), cellSets[here.id, tid]);
}

// Combine sets...
// Might want to use PropertyMap since its significantly faster and
// has aggregation and is concurrent... TODO!!!
var cellSet : domain(Cell, parSafe=true) dmapped Hashed(idxType=Cell);
for cset in cellSets {
	forall cell in cset with (ref cellSet) {
		cellSet += cell;
	}
}

/*bin k-cells, with key as the length of the list and value is a list with all the k-cells*/
// TODO: Perform reduction like above...
var kCellMap = new map(int, list(Cell, parSafe=true), parSafe=true); // potential bottleneck...
forall cell in cellSet {
	kCellMap[cell.size].append(cell);
}

for k in kCellMap do kCellMap[k].sort();

for k in kCellMap.keys {
	writeln(k, " -> ", kCellMap[k]);
}

class kCellsArray{
	var numKCells : int;
	var D = {1..numKCells} dmapped Cyclic(startIdx=1);
	var A : [D] Cell;
	proc init(_N: int) {
		numKCells = _N;
	}
	proc findCellIndex(cell : Cell) {
		return search(A, cell);
	}
}

var numBins = kCellMap.size - 1;
var kCellsArrayMap : [0..numBins] owned kCellsArray?;
var kCellKeys = kCellMap.keysToArray();
sort(kCellKeys);

// Leader-follower iterator
// Create the new KcellMaps for convenience of sorting
forall (_kCellsArray, kCellKey) in zip(kCellsArrayMap, kCellKeys) {
	_kCellsArray = new owned kCellsArray(kCellMap[kCellKey].size);
	_kCellsArray.A = kCellMap[kCellKey].toArray(); 
	sort(_kCellsArray.A, comparator=absComparator);
}

/*Start of the construction of boundary matrices.*/
class Matrix {
	var N : int;
	var M : int;
	var D = {0..#N, 0..#M} dmapped Block(boundingBox = {1..N, 1..M});
	var matrix : [D] int;
	proc init(_N: int, _M:int) {
		N = _N;
		M = _M;
	}

	proc readWriteThis(f) {
		f <~> matrix;
	}

	proc this(i,j) ref return matrix[i,j];

	iter these() ref {
		for x in matrix do yield x;
	}
}

var boundaryMaps : [1..#kCellMap.size - 1] owned Matrix?;

// Leader-follower iterator
// Create the boundary Maps
forall (boundaryMap, dimension_k_1, dimension_k) in zip(boundaryMaps, 0.., 1..) {
	boundaryMap = new owned Matrix(kCellsArrayMap[dimension_k_1].numKCells, kCellsArrayMap[dimension_k].numKCells);
}

for (idx, k) in zip(boundaryMaps.domain, boundaryMaps) {
	writeln(idx, ":\n", boundaryMaps[idx]);
}

// Compute values for each entries in each of the boundary map
forall (boundaryMap, dimension_k_1, dimension_k) in zip(boundaryMaps, 0.., 1..) {
	var ACells = kCellsArrayMap[dimension_k].A;
	var BCells = kCellsArrayMap[dimension_k_1].A;

	// Mappings for permutation to index...
	var k1Mapping : map(false, Cell, int);
	for (k1Cell, idx) in zip(kCellMap[dimension_k_1 + 1], 0..) {
		k1Mapping[k1Cell] = idx;
	}

	for (acell, j) in zip(ACells, 0..) {
		var perms = splitKCell(acell);
		for match in intersection(perms, BCells) {
			boundaryMap[k1Mapping[match], j] = 1;
		}
	}
}

proc printBoundaryMap(boundaryMap) {
	var row : int = boundaryMap.matrix.domain.high(1);
	var col : int = boundaryMap.matrix.domain.high(2);
	for i in 0..#row {
		for j in 0..#col {
			write(boundaryMap.matrix[i, j] : string + " ");
		}
		writeln();
	}
}

for (boundaryMap, dimension_k_1, dimension_k) in zip(boundaryMaps, 0.., 1..) {
	writeln("Printing boundary map for: " : string + dimension_k_1 : string + " " :string + dimension_k : string);
	printBoundaryMap(boundaryMap);
}
