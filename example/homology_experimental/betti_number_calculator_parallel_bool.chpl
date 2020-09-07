use PropertyMaps;
use AdjListHyperGraphs;
use WorkQueues;
use TerminationDetections;
use Time; // For Timer
use Set;
use Map;
use List;
use Sort;
use Search;
use Regexp;
use FileSystem;
use BigInteger;
use HashedDist;
use CyclicDist;
use VisualDebug;
use Utilities;
use BlockDist;

config const datasetDir = "./betti_test_data/";
/*
  Output directory.
*/
config const outputDirectory = "tmp/";
// Maximum number of files to process.
config const numMaxFiles = max(int(64));

var files : list(string);
var vPropMap = new PropertyMap(string);
var ePropMap = new PropertyMap(string);
var wq = new WorkQueue(string, 1024);
var td = new TerminationDetector();
var t = new Timer();
var total_time = new Timer();
total_time.start();

proc printPropertyDistribution(propMap) : void {
  var localNumProperties : [LocaleSpace] int;
  coforall loc in Locales do on loc do localNumProperties[here.id] = propMap.numProperties();
  var globalNumProperties = + reduce localNumProperties;
  for locid in LocaleSpace {
    writeln("Locale#", locid, " has ", localNumProperties[locid], "(", localNumProperties[locid] : real / globalNumProperties * 100, "%)");
  }
}

//Need to create outputDirectory prior to opening files
if !exists(outputDirectory) {
   try {
      mkdir(outputDirectory);
   }
   catch {
      halt("*Unable to create directory ", outputDirectory);
   }
}
// Fill work queue with files to load up
var currLoc : int; 
var nFiles : int;
var fileNames : list(string);
for fileName in listdir(datasetDir, dirs=false) {
    if !fileName.endsWith(".csv") then continue;
    if nFiles == numMaxFiles then break;
    files.append(fileName);
    fileNames.append(datasetDir + fileName);
    currLoc += 1;
    nFiles += 1;
}

// Spread out the work across multiple locales.
var _currLoc : atomic int;
forall fileName in fileNames {
  td.started(1);
  wq.addWork(fileName, _currLoc.fetchAdd(1) % numLocales);
}
wq.flush();


// Initialize property maps; aggregation is used as properties can be remote to current locale.
forall fileName in doWorkLoop(wq, td) {
  for line in getLines(fileName) {
    var attrs = line.split(",");
    var qname = attrs[0].strip();
    var rdata = attrs[1].strip();

    vPropMap.create(rdata, aggregated=true);
    ePropMap.create(qname, aggregated=true);
  }
  td.finished();  
}
vPropMap.flushGlobal();
ePropMap.flushGlobal();
// t.stop();
writeln("Constructed Property Map with ", vPropMap.numPropertiesGlobal(), 
    " vertex properties and ", ePropMap.numPropertiesGlobal(), 
    " edge properties in ", t.elapsed(), "s");
t.clear();

writeln("Vertex Property Map");
printPropertyDistribution(vPropMap);
writeln("Edge Property Map");
printPropertyDistribution(ePropMap);

writeln("Constructing HyperGraph...");
t.start();
var hypergraph = new AdjListHyperGraph(vPropMap, ePropMap, new unmanaged Cyclic(startIdx=0));
t.stop();
writeln("Constructed HyperGraph in ", t.elapsed(), "s");
t.clear();
writeln("Populating HyperGraph...");

t.start();
// Spread out the work across multiple locales.
_currLoc.write(0);
forall fileName in fileNames {
  td.started(1);
  wq.addWork(fileName, _currLoc.fetchAdd(1) % numLocales);
}
wq.flush();

// Aggregate fetches to properties into another work queue; when we flush
// each of the property maps, their individual PropertyHandle will be finished.
// Also send the 'String' so that it can be reclaimed.
var handleWQ = new WorkQueue((unmanaged PropertyHandle?, unmanaged PropertyHandle?), 64 * 1024);
var handleTD = new TerminationDetector();
forall fileName in doWorkLoop(wq, td) {
  for line in getLines(fileName) {
    var attrs = line.split(",");
    var qname = attrs[0].strip();
    var rdata = attrs[1].strip();
    handleTD.started(1);
    handleWQ.addWork((vPropMap.getPropertyAsync(rdata), ePropMap.getPropertyAsync(qname)));
  }
  td.finished();
}
vPropMap.flushGlobal();
ePropMap.flushGlobal();

// Finally aggregate inclusions for the hypergraph.
hypergraph.startAggregation();
forall (vHandle, eHandle) in doWorkLoop(handleWQ, handleTD) {
  hypergraph.addInclusion(vHandle!.get(), eHandle!.get());
  delete vHandle;
  delete eHandle;
  handleTD.finished(1);
}
hypergraph.stopAggregation();
hypergraph.flushBuffers();

t.stop();
writeln("Populated HyperGraph in ", t.elapsed(), "s");
t.clear();
writeln("Number of Inclusions: ", hypergraph.getInclusions());
writeln("Deleting Duplicate edges: ", hypergraph.removeDuplicates());
writeln("Number of Inclusions: ", hypergraph.getInclusions());

t.start();
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

proc chpl__defaultHash(cell : Cell) {
  var hash : uint(64) = chpl__defaultHash(cell.size);
  for (ix, a) in zip(1.., cell) {
    // chpl__defaultHashCombine passed '17 + fieldnum' so we can only go up to 64 - 17 = 47
    hash = chpl__defaultHashCombine(chpl__defaultHash(a), hash, ix % 47);
  }
  return hash;
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
proc processCell (kcell, ref cellSet) {
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
var cellSets : [0..#numLocales, 1..here.maxTaskPar] set(Cell);
// TODO: Use Privatized to cut down communication...
var taskIdCounts : [0..#numLocales] atomic int; 
forall e in hypergraph.getEdges() with (var tid : int = taskIdCounts[here.id].fetchAdd(1), ref cellSets) {
  var vertices = hypergraph.incidence(e); // ABCD
  ref tmp = vertices[0..#vertices.size-1];
  var verticesInEdge : [0..#vertices.size-1] int = tmp.id;
  processCell(new Cell(verticesInEdge), cellSets[here.id, tid]);
}

writeln("Permutation done");

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
forall cell in cellSet with (ref kCellMap) {
  kCellMap[cell.size - 1].append(cell);
}

for k in kCellMap do kCellMap[k].sort();

writeln("Sort 1 done");
/* for k in kCellMap.keys { */
/*   writeln(k, " -> ", kCellMap[k]); */
/* } */

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
writeln("Sort 2 done");
// Leader-follower iterator
// Create the new KcellMaps for convenience of sorting
forall (_kCellsArray, kCellKey) in zip(kCellsArrayMap, kCellKeys) {
  _kCellsArray = new owned kCellsArray(kCellMap[kCellKey].size);
  _kCellsArray!.A = kCellMap[kCellKey].toArray(); 
  sort(_kCellsArray!.A, comparator=absComparator);
}


writeln("Starting computing boundary matrix");

config param useLocalArray = (CHPL_COMM == "none");
/*Start of the construction of boundary matrices.*/
class Matrix {
  var N : int;
  var M : int;
  const D = if useLocalArray then {1..N, 1..M}
  else {1..N, 1..M} dmapped Block(boundingBox = {1..N, 1..M});
  // var D = {1..N, 1..M} dmapped Block(boundingBox = {1..N, 1..M});
  var matrix : [D] bool;
  proc init(_N: int, _M:int) {
    N = _N;
    M = _M;
  }

  proc dom ref return D;

  proc readWriteThis(f) {
    f <~> matrix;
  }

  proc this(i,j) ref return matrix[i,j];

  iter these() ref {
    for x in matrix do yield x;
  }
}


// var boundaryMaps : [1..#kCellMap.size - 1] owned Matrix?;
var boundaryMaps : [1..3] owned Matrix?;

// Leader-follower iterator
// Create the boundary Maps
forall (boundaryMap, dimension_k_1, dimension_k) in zip(boundaryMaps, 0.., 1..) {
  boundaryMap = new owned Matrix(kCellsArrayMap[dimension_k_1]!.numKCells, kCellsArrayMap[dimension_k]!.numKCells);
}

/* for (idx, k) in zip(boundaryMaps.domain, boundaryMaps) { */
/*   writeln(idx, ":\n", boundaryMaps[idx]); */
/* } */

// Compute values for each entries in each of the boundary map
forall (boundaryMap, dimension_k_1, dimension_k) in zip(boundaryMaps, 0.., 1..) {
  var ACells = kCellsArrayMap[dimension_k]!.A;
  var BCells = kCellsArrayMap[dimension_k_1]!.A;

  // Mappings for permutation to index...
  var k1Mapping : map(Cell, int, false);
  for (k1Cell, idx) in zip(kCellMap[dimension_k_1], 1..) {
    k1Mapping[k1Cell] = idx;
  }

  forall (acell, colidx) in zip(ACells, 1..) {
    var perms = splitKCell(acell);
		
    for bcell in BCells {
      for cell in perms {
        if bcell == cell {
          boundaryMap![k1Mapping[cell], colidx] = true;
          break;
        }
      }
    }
  }
}

proc printBoundaryMap(boundaryMap) {
  var row : int = boundaryMap!.matrix.domain.high(0);
  var col : int = boundaryMap!.matrix.domain.high(1);
  for i in boundaryMap!.matrix.domain.dim(0) {
    for j in boundaryMap!.matrix.domain.dim(1) {
      write(boundaryMap!.matrix[i, j] : string + " ");
    }
    writeln();
  }
}

/* for (boundaryMap, dimension_k_1, dimension_k) in zip(boundaryMaps, 0.., 1..) { */
/*   writeln("Printing boundary map for: " : string + dimension_k_1 : string + " " :string + dimension_k : string); */
/*   printBoundaryMap(boundaryMap); */
/* } */
t.stop();
writeln("Boundary map calculation took ", t.elapsed(), " s");
t.clear();

t.start();
proc IdentityMatrix(n) {
  var A : [1..n, 1..n] bool;
  [i in A.domain.dim(0)] A[i,i] = true;
  return A;
}

proc _get_next_pivot(M, s1, in s2 : int = -1) {
  var dims = M.domain.high;
  var dimR = dims(0);
  var dimC = dims(1);
  if (s2 == -1) {
    s2 = s1;
  }
  for c in s2..dimC {
    for r in s1..dimR {
      if (M(r,c) != 0) {
      	return (r,c);
      }
    }
  }
  return (-1,-1); // TODO: return
}


proc swap_rows(i, j, M) {
  var N = M;
  // N[i, ..] <=> N[j, ..];
  // N[i..i, ..] <=> N[j..j, ..];
  forall k in N.domain.dim(1) do
    N[i, k] <=> N[j, k];
  return N;
}

proc swap_columns(i, j, M) {
  var N = M;
  // N[.., i] <=> N[.., j];
  // N[.., i..i] <=> N[.., j..j];
  forall k in N.domain.dim(0) do
    N[k, i] <=> N[k, j];
  return N;
}

// Replaces row i (of M) with sum ri multiple of ith row and rj multiple of jth row
proc add_to_row(M, i, j,  mod = 2) {
  var N = M;
  // N[i, ..]  = (N[i, ..] ^  N[j, ..]);
  // N[i, ..]  ^=   N[j, ..];
  forall k in N.domain.dim(1) do
    N[i, k] ^= N[j, k];
  // N[i..i, ..]  ^=   N[j..j, ..];
  return N;
}


proc add_to_column(M, i, j, mod = 2) {
  var N = M;
  // N[.., i]  = (N[.., i] ^ N[..,j]);
  // N[.., i]  ^=  N[..,j];
  forall k in N.domain.dim(0) do
    N[k, i] ^= N[k, j];
  // N[.., i..i]  ^=  N[..,j..j];
  return N;
}


proc matmultmod (M, N, mod = 2) {
  var CD = {M.domain.dim(0), N.domain.dim(1)} dmapped Block(boundingBox = {M.domain.dim(0), N.domain.dim(1)});
  var C : [CD] int;
  forall (i,j) in C.domain {
    C[i,j] = (+ reduce (M[i, M.domain.dim(1)] * N[M.domain.dim(1), j])) % 2;
  }
  return C;
}

/*
def logical_matmul(mat1,mat2):
    L1,R1 = mat1.shape
    L2,R2 = mat2.shape
    if R1 != L2:
        raise HyperNetXError("logical_matmul called for matrices with inner dimensions mismatched")

    mat = np.zeros((L1,R2), dtype=bool)
    mat2T = mat2.transpose()          
    for i in range(L1):
        if np.any(mat1[i]):
            for j in range(R2):
                mat[i,j] = logical_dot(mat1[i],mat2T[j])
        else:
            mat[i] = np.zeros((1,R2),dtype=bool)
    return mat

def logical_dot(ar1,ar2):
if len(ar1)!=len(ar2):
  raise HyperNetXError('logical_dot requires two 1-d arrays of the same length')
 else:
   return np.logical_xor.reduce(np.logical_and(ar1,ar2))

*/
proc transpose(N) {
  var NTD = {N.domain.dim(1), N.domain.dim(0)};
  var NT : [NTD] bool;
  for i in N.domain.dim(1) {
    NT[i,..] = N[..,i];
  }
  return NT;
}

proc logical_dot(a, b) {
  return (^ reduce (a & b));

}
proc logical_matmul(M,N) {
  var CD = {M.domain.dim(0), N.domain.dim(1)};
  var C : [CD] bool;
  var NT = transpose(N);
  for i in M.domain.dim(0) {
    //TODO: if np.any(mat1[i]):                                                                                                                                              
    for j in N.domain.dim(1) {
      C[i, j] = logical_dot(M[i, ..], NT[j, ..]);
    }
  }
  return C;
}

// TODO: Just work on Matrix instead of raw 2D arrays
type listType = list(unmanaged Matrix?, true);
proc matmulreduce(arr : listType, reverse = false, mod = 2) {
  var PD = arr[if reverse then arr.size else 1].D;
  var P : [PD] int;
  if (reverse) {
    P = arr(arr.size).matrix; // bulk copy
    for i in 1..#arr.size - 1 by -1 {
      ref temp = matmultmod(P, arr(i).matrix);
      PD = temp.domain;
      P = temp;
    }
  } else {
    P = arr(1).matrix; // bulk copy
    for i in 2..arr.size {
      ref temp = matmultmod(P, arr(i).matrix);
      PD = temp.domain;
      P = temp;
    }
  }
  return P;
}

// rank calculation:
/* proc calculateRank(M) { */
/*   var rank = + reduce [i in M.domain.dim(2)] (max reduce M[.., i]); */
/*   return rank; */
/* } */

proc calculateRank(M) {
  var rank = + reduce [i in M.domain.dim(1)] ((|| reduce M[.., i]) : int);
  return rank;
}

// printmatrix(b);

proc smithNormalForm(b) {
  var dims = b.domain.high;
  var dimL = dims(0);
  var dimR = dims(1);
  var minDim = if dimL <= dimR then dimL else dimR;
 
  // writeln(dimL : string ); // dims give me the index set but I need the max value of the index set
  // writeln(minDim);


  var S  = b;
  var IL = IdentityMatrix(dimL);
  var IR = IdentityMatrix(dimR);

  /* var Linv = new list(unmanaged Matrix?, true); // listOfMatrixTransformation */
  /* var Rinv = new list(unmanaged Matrix?, true); // listOfMatrixTransformation */

  /* var Linit = new unmanaged Matrix(IL.domain.high(1), IL.domain.high(2)); */
  /* Linit.matrix = IL; */
  /* Linv.append(Linit); */
  /* var Rinit = new unmanaged Matrix(IR.domain.high(1), IR.domain.high(2)); */
  /* Rinit.matrix = IR; */
  /* Rinv.append(Rinit); */

  var L = IL;
  var R = IR;
  var Linv = IL;

  /* writeln("###############"); */
  /* writeln("L:"); */
  /* printmatrix(L); */
  /* writeln("###############"); */
  /* writeln("R:"); */
  /* printmatrix(R); */

  // var rc = _get_next_pivot(b, 3);
  // writeln(rc : string);


  writeln("########");
  for s in 1..minDim {
    // var t = new Timer();
    // t.start();
    /* writeln("Iteration: " +  s : string); */
    var pivot = _get_next_pivot(S,s);
    var rdx : int, cdx : int;
    if (pivot(0) == -1 && pivot(1) == -1) {
      break;
    }
    else {
      (rdx, cdx) = pivot;
    }
 
    // Swap rows and columns as needed so the 1 is in the s,s position
    if (rdx > s) {
      S = swap_rows(s, rdx, S);
      L = swap_rows(s, rdx, L);
      Linv = swap_columns(rdx, s, Linv);
    }
    if (cdx > s) {
      S = swap_columns(s, cdx, S);
      R = swap_columns(s, cdx, R);
    }

    // add sth row to every nonzero row & sth column to every nonzero column
    // zip(S[.., s], S.dim(1)) gives you (S[i,j], 1..N)
    // row_indices = [idx for idx in range(dimL) if idx != s and S[idx][s] == 1]
    // var RD: domain(2) = {1..dimL, 1..dimL};
    // var row_indices = [(x,(i,j)) in zip(S, 1..dimL)] if x == 1 && j != s then (i,j);
    // var row_indices = [(s,idx) in zip(S, {1..dimL})] if s == 1 then idx;

    var row_indices = [idx in s + 1..dimL] if (S(idx,s) == 1) then idx;
    // compilerWarning(row_indices.type : string);

    for rdx in row_indices {
      // writeln("rdx: " + rdx : string);
      S = add_to_row(S, rdx, s);
      L = add_to_row(L, rdx, s);
      Linv = add_to_column(Linv, s, rdx);
    }

    var column_indices = [jdx in s + 1..dimR] if (S(s,jdx) == 1) then jdx;
 
    for cdx in column_indices {// TODO: check
      // writeln("rdx: " + rdx : string);
      S = add_to_column(S, cdx, s);
      R = add_to_column(R, cdx, s);
    }
    // t.stop();
    // writeln("Iteration ", s, " took ", t.elapsed());
  }


  return (L,R,S,Linv);
}

// @TODO: typeof return type of snf function?
/* var CM : [1..3] list(unmanaged Matrix?, true); */
/* //startVdebug("SNF"); */
/* var tt = new Timer(); */
/* tt.start(); */
/* for i in 1..3 { */
/*   CM[i] = smithNormalForm(boundaryMaps[i].matrix); */
/* } */

var computedMatrices = smithNormalForm(boundaryMaps[1]!.matrix);
var computedMatrices2 = smithNormalForm(boundaryMaps[2]!.matrix);
var computedMatrices3 = smithNormalForm(boundaryMaps[3]!.matrix);
var L1 = computedMatrices(0);
var R1 = computedMatrices(1);
var S1 = computedMatrices(2);
var L1invF = computedMatrices(3);
var L2 = computedMatrices2(0);
var R2 = computedMatrices2(1);
var S2 = computedMatrices2(2);
var L2invF = computedMatrices2(3);
var L3 = computedMatrices3(0);
var R3 = computedMatrices3(1);
var S3 = computedMatrices3(2);
var L3invF = computedMatrices3(3);
var rank1 = calculateRank(S1);
var rank2 = calculateRank(S2);
var nullity1 = S1.domain.high(1) - rank1;
var betti1 = S1.domain.high(1) - rank1 - rank2;
writeln("Betti 1: " + betti1 : string);

/* var rank3 = calculateRank(S2); */
/* writeln("Rank of S2: " + rank1  : string); */
var rank3 = calculateRank(S3);
var betti2 = S2.domain.high(1) - rank2 - rank3;
writeln("Betti 2: " + betti2 : string);
writeln("Betti number calculation took ", t.elapsed(), " s");
t.clear();
writeln("Total execution time: " + total_time.elapsed() : string +  " s");
//stopVdebug();