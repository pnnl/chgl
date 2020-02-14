/*Homology computation on small DNS datasets*/
/*To compile : chpl -o homology_dns --fast --cc-warnings -M../../src --dynamic --no-lifetime-checking --no-warnings homology_dns.chpl */

use CHGL; // Includes all core and utility components of CHGL
use Time; // For Timer
use Set;
use Map;
use List;
use Sort;
use Search;
use Regexp;
use FileSystem;
use BigInteger;

config const datasetDirectory = "./homology_dns_data/";
/*
  Output directory.
*/
config const outputDirectory = "tmp/";
// Maximum number of files to process.
config const numMaxFiles = max(int(64));

var files : [0..-1] string;
var vPropMap = new PropertyMap(string);
var ePropMap = new PropertyMap(string);
var wq = new WorkQueue(string, 1024);
var td = new TerminationDetector();
var t = new Timer();

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
var fileNames : [0..-1] string;
for fileName in listdir(datasetDirectory, dirs=false) {
    if !fileName.endsWith(".csv") then continue;
    if nFiles == numMaxFiles then break;
    files.push_back(fileName);
    fileNames.push_back(datasetDirectory + fileName);
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
    var qname = attrs[1].strip();
    var rdata = attrs[2].strip();

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
    var qname = attrs[1].strip();
    var rdata = attrs[2].strip();
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
  hypergraph.addInclusion(vHandle.get(), eHandle.get());
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
  /* writeln(stringify(verticesSet)); */
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
  ref tmp = vertices[1..#vertices.size];
  var verticesInEdge : [1..#vertices.size] int;
  verticesInEdge[1..#vertices.size] = tmp.id; // ABCD vertices.low
  doProcessVertices(verticesInEdge);
}

/* writeln("Printing all generated combination"); */
/* /\*Verify the set by printing*\/ */
/* var setContent = _vtxSubsetSet.toArray(); */
/* for c in setContent do */
/*   writeln(c); */

/* writeln("-----"); */
/* writeln("Printing bins"); */
/*bin k-cells, with key as the length of the list and value is a list with all the k-cells*/
var kCellMap = new map(int, list(string, true));
for vtxSet in _vtxSubsetSet {
  var sz = + reduce [ch in vtxSet] ch == ' ';
  /* writeln(sz : string + " " + vtxSet : string); */
  kCellMap[sz].append(vtxSet);
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
proc Comparator.compare(a :string, b :string) : int {
  var retVal : int = 0;
  if (b == "" || a == "") {
    /* writeln("a: " + a : string + " b: " + b : string); */
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

/* /\* writeln("%%%%%%%%%%%%%"); *\/ */
/* // Leader-follower iterator */
/* // Create the new KcellMaps for convenience of sorting */
for (_kCellsArray, kCellKey) in zip(kCellsArrayMap, kCellKeys) {
  /* writeln("kCellkey:" + kCellKey : string); */
  /* writeln("listsize: " + kCellMap[kCellKey].size : string); */
  _kCellsArray = new owned kCellsArray(kCellMap[kCellKey].size);
  _kCellsArray.A = kCellMap[kCellKey].toArray();
  sort(_kCellsArray.A, comparator=absComparator);
}
/* writeln("%%%%%%%%%%%%%"); */

/* writeln("Printing after sorting"); */
/* writeln("^^^^^^^^^^^^^^^^^^^^^^^"); */
/* for _kCellsArray in kCellsArrayMap { */
/*   writeln(_kCellsArray.A : string); */
/* } */
/* writeln("^^^^^^^^^^^^^^^^^^^^^^^"); */

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
  /* writeln("dimensions: " + kCellsArrayMap[dimension_k_1].numKCells: string + " " + kCellsArrayMap[dimension_k].numKCells : string); */
  boundaryMap = new owned Matrix(kCellsArrayMap[dimension_k_1].numKCells, kCellsArrayMap[dimension_k].numKCells);
}

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


/* writeln("####"); */
// Compute values for each entries in each of the boundary map
for (dimension_k_1, dimension_k) in zip(0..2, 1..3) {
  var arrayOfKCells  = kCellsArrayMap[dimension_k].A; // Arrays of strings, each string being 1 kcell
  var arrayOfK_1Cells = kCellsArrayMap[dimension_k_1].A;
  /* writeln("$$$$$$$$$$$"); */
  /* writeln(arrayOfKCells); */
  /* writeln(arrayOfK_1Cells); */
  /* writeln("$$$$$$$$$$$"); */
  var i : int = 0;
  var j : int = 0;
  for SkCell in arrayOfKCells { // iterate through all the k-cells
    i = i + 1;
    /* Generate permutation of the current k-Cell*/
    var kCell = SkCell.split(" ") : int;
    /* writeln("#kcell: " + kCell :string); */
    /* writeln("Combinations generated ": string); */
    for sc in processVtxSubset(kCell) {
      var st = stringify(sc);
      j = 0;
      for Sk_1Cell in arrayOfK_1Cells {
	j = j + 1;
	if (st == Sk_1Cell) {
	  // writeln(st :string + "matches");
	  boundaryMaps[dimension_k].matrix[j, i] = 1;
	  break;
	}
      }
    }
  }
  /* writeln("$$$$$$$$$$$"); */
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

/* for (dimension_k_1, dimension_k) in zip(0..1, 1..2) { */
/*   writeln("Printing boundary map for: " : string + dimension_k_1 : string + " " :string + dimension_k : string); */
/*   printBoundaryMap(boundaryMaps[dimension_k]); */
/* } */


proc printmatrix(M) {
  for i in {1..M.domain.high(1)} {
    for j in {1..M.domain.high(2)} {
      write(M(i,j):string + " ");
    }
    writeln();
  }
}


proc IdentityMatrix(n) {
  var A : [1..n, 1..n] int;
  [i in A.domain.dim(1)] A[i,i] = 1;
  return A;
}

use List;
class Matrix2D {
  var N : int;
  var M : int;
  var _arr : [1..N, 1..M] int;
  proc init (row : int, col : int) {
    N = row;
    M = col;
  }
}

proc _get_next_pivot(M, s1, in s2 : int = 0) {
  var dims = M.domain.high;
  var dimR = dims(1);
  var dimC = dims(2);
  if (s2 == 0) {
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
  N[i, ..] <=> N[j, ..];
  return N;
}

proc swap_columns(i, j, M) {
  var N = M;
  N[.., i] <=> N[.., j];
  return N;
}

// Replaces row i (of M) with sum ri multiple of ith row and rj multiple of jth row
proc add_to_row(M, i, j, ri = 1, rj = 1, mod = 2) {
  var N = M;
  N[i, ..]  = (ri * N[i, ..] + rj * N[j, ..]) % mod;
  return N;
}


proc add_to_column(M, i, j, ci = 1, cj = 1, mod = 2) {
  var N = M;
  N[.., i]  = (ci * N[.., i] + cj * N[..,j]) % mod;
  return N;
}

proc matmultmod2 (M, N, mod = 2) {
  var nr = M.domain.high(1);
  var nc = N.domain.high(2);
  var m  = M.domain.high(2);
  var C : [1..nr, 1..nc] atomic int;

  forall i in 1..nr {
    for j in 1..nc {
      C[i,j].write((+ reduce M[i, 1..m] * N[1..m, j]) % 2) ;
    }
  }
  return C.read();
}

proc matmultmod3 (M, N, mod = 2) {
  var C : [M.domain.dim(1), N.domain.dim(2)] atomic int;
  forall (i,j) in C.domain {
    C[i,j].write((+ reduce M[i, M.domain.dim(2)] * N[M.domain.dim(2), j]) % 2);
  }
  return C.read();
}

proc matmultmod (M, N, mod =2) {
  var C : [M.domain.dim(1), N.domain.dim(2)] int;
  forall (i,j) in C.domain {
    C[i,j] = (+ reduce (M[i, M.domain.dim(2)] * N[M.domain.dim(2), j])) % 2;
  }
  return C;
}

type listType = list(unmanaged Matrix2D?, true);
proc matmulreduce(arr : listType, reverse = false, mod = 2) {
  var PD: domain(2) = {1..arr(1)._arr.domain.high(1), 1..arr(1)._arr.domain.high(2)};
  var P : [PD] int;
  if (reverse) {
    PD = {1..arr(arr.size)._arr.domain.high(1), 1..arr(arr.size)._arr.domain.high(2)};
    P = arr(arr.size)._arr;
    for i in 1..#arr.size - 1 by -1 {
      var tempD : domain(2) = {1..P.domain.high(1), 1..arr(i)._arr.domain.high(2)};
      var temp : [tempD] int;
      temp = matmultmod(P, arr(i)._arr);
      PD = tempD;
      P = temp;
    }
  } else {
    P = arr(1)._arr;
    for i in 2..arr.size {
      var tempD : domain(2) = {1..P.domain.high(1), 1..arr(i)._arr.domain.high(2)};
      var temp : [tempD] int;
      temp = matmultmod(P, arr(i)._arr);
      PD = tempD;
      P = temp;
    }
  }
  return P;
}

// rank calculation:
proc calculateRank(M) {
  var rank = + reduce [i in M.domain.dim(2)] (max reduce M[.., i]);
  return rank;
}


// printmatrix(b);

proc smithNormalForm(b) {
  var dims = b.domain.high;
  var dimL = dims(1);
  var dimR = dims(2);
  var minDim = if dimL <= dimR then dimL else dimR;
 
  // writeln(dimL : string ); // dims give me the index set but I need the max value of the index set
  // writeln(minDim);


  var S  = b;
  var IL = IdentityMatrix(dimL);
  var IR = IdentityMatrix(dimR);

  var Linv = new list(unmanaged Matrix2D?, true); // listOfMatrixTransformation
  var Rinv = new list(unmanaged Matrix2D?, true); // listOfMatrixTransformation

  var Linit = new unmanaged Matrix2D(IL.domain.high(1), IL.domain.high(2));
  Linit._arr = IL;
  Linv.append(Linit);
  var Rinit = new unmanaged Matrix2D(IR.domain.high(1), IR.domain.high(2));
  Rinit._arr = IR;
  Rinv.append(Rinit);

  var L = IL;
  var R = IR;

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
    /* writeln("Iteration: " +  s : string); */
    var pivot = _get_next_pivot(S,s);
    var rdx : int, cdx : int;
    if (pivot(1) == -1 && pivot(2) == -1) {
      break;
    }
    else {
      (rdx, cdx) = pivot;
    }
 
    // Swap rows and columns as needed so the 1 is in the s,s position
    if (rdx > s) {
      S = swap_rows(s, rdx, S);
      L = swap_rows(s, rdx, L);
      var tmp = swap_rows(s, rdx, IL);
      var LM = new unmanaged Matrix2D(tmp.domain.high(1), tmp.domain.high(2));
      LM._arr = tmp;
      Linv.append(LM);
    }
    if (cdx > s) {
      S = swap_columns(s, cdx, S);
      R = swap_columns(s, cdx, R);
      var tmp = swap_columns(s, cdx, IR);
      var RM = new unmanaged Matrix2D(tmp.domain.high(1), tmp.domain.high(2));
      RM._arr = tmp;
      Rinv.append(RM);
    }

    // add sth row to every nonzero row & sth column to every nonzero column
    // zip(S[.., s], S.dim(1)) gives you (S[i,j], 1..N)
    // row_indices = [idx for idx in range(dimL) if idx != s and S[idx][s] == 1]
    // var RD: domain(2) = {1..dimL, 1..dimL};
    // var row_indices = [(x,(i,j)) in zip(S, 1..dimL)] if x == 1 && j != s then (i,j);
    // var row_indices = [(s,idx) in zip(S, {1..dimL})] if s == 1 then idx;

    var row_indices = [idx in 1..dimL] if (idx != s && S(idx,s) == 1) then idx;
    // compilerWarning(row_indices.type : string);

    for rdx in row_indices {
      // writeln("rdx: " + rdx : string);
      S = add_to_row(S, rdx, s);
      L = add_to_row(L, rdx, s);
      var tmp = add_to_row(IL, rdx, s);
      var LM = new unmanaged Matrix2D(tmp.domain.high(1), tmp.domain.high(2));
      LM._arr = tmp;
      Linv.append(LM);
    }

    var column_indices = [jdx in 1..dimR] if (jdx != s && S(s,jdx) == 1) then jdx;
 
    for (jdx,cdx) in zip(1..,column_indices) {// TODO: check
      // writeln("rdx: " + rdx : string);
      S = add_to_column(S, cdx, s);
      R = add_to_column(R, cdx, s);
      var tmp = add_to_column(IR, cdx, s);
      var RM = new unmanaged Matrix2D(tmp.domain.high(1), tmp.domain.high(2));
      RM._arr = tmp;
      Rinv.append(RM);
    }
  }


  var LinvF = matmulreduce(Linv);
  var RinvF = matmulreduce(Rinv, true, 2);
  return (L,R,S,LinvF,RinvF);
}

var computedMatrices = smithNormalForm(boundaryMaps[1].matrix);
var computedMatrices2 = smithNormalForm(boundaryMaps[2].matrix);
var computedMatrices3 = smithNormalForm(boundaryMaps[3].matrix);
var L1 = computedMatrices(1);
var R1 = computedMatrices(2);
var S1 = computedMatrices(3);
var L1invF = computedMatrices(4);
var R1invF = computedMatrices(5);
var L2 = computedMatrices2(1);
var R2 = computedMatrices2(2);
var S2 = computedMatrices2(3);
var L2invF = computedMatrices2(4);
var R2invF = computedMatrices2(5);
var L3 = computedMatrices3(1);
var R3 = computedMatrices3(2);
var S3 = computedMatrices3(3);
var L3invF = computedMatrices3(4);
var R3invF = computedMatrices3(5);
writeln("###############");
writeln("L1:");
printmatrix(L1);
writeln("###############");
writeln("R1:");
printmatrix(R1);
writeln("###############");
writeln("S1:");
printmatrix(S1);
writeln("###############");
writeln("L1inv:");
printmatrix(L1invF);
writeln("###############");
writeln("R1inv:");
printmatrix(R1invF);
writeln("###############");
writeln("L2inv:");
printmatrix(L2invF);

var rank1 = calculateRank(S1);
writeln("Rank of S1: " + rank1  : string);
var rank2 = calculateRank(S2);
writeln("Rank of S2: " + rank2  : string);
var nullity1 = S1.domain.high(2) - rank1;
var betti1 = S1.domain.high(2) - rank1 - rank2;
writeln("Betti 1: " + betti1 : string);

/* var rank3 = calculateRank(S2); */
/* writeln("Rank of S2: " + rank1  : string); */
var rank3 = calculateRank(S3);
writeln("Rank of S3: " + rank3  : string);
// var betti2 = S2.domain.high(2) - rank2 - rank3;
// writeln("Betti 2: " + betti2 : string);

var cokernel2_dim = S1.domain.high(2) - rank2;

var nr1 = R1.domain.high(2) - rank1;
var ker1 : [1..R1.domain.high(1), 1..nr1] int = R1[..,rank1+1..];
writeln("###############");
writeln("ker1:");
printmatrix(ker1);

//     im2 = L2inv[:,:rank2]
var im2 : [1..L2invF.domain.high(1), 1..rank2] int = L2invF[..,1..rank2];
var nr2 = L2invF.domain.high(2) - rank2;
var cokernel2 : [1..L2invF.domain.high(1), 1..nr2] int = L2invF[..,rank2 + 1..];

writeln("###############");
writeln("Cokernel:");
printmatrix(cokernel2);

writeln("###############");
writeln("L2:");
printmatrix(L2);

var LKernel = new list(unmanaged Matrix2D?, true);

var _L2 = new unmanaged Matrix2D(L2.domain.high(1), L2.domain.high(2));
_L2._arr = L2;
LKernel.append(_L2);

var _ker1 = new unmanaged Matrix2D(ker1.domain.high(1), ker1.domain.high(2));
_ker1._arr = ker1;
LKernel.append(_ker1);

writeln("L2 dimension: " + L2.domain.high(1) :string + "X" + L2.domain.high(2):string);
writeln("ker1 dimension: " + ker1.domain.high(1) :string + "X" + ker1.domain.high(2):string);

var result =  matmulreduce(LKernel);
var slc = result.domain.high(1) - rank2;
var proj : [1..slc, 1..result.domain.high(2)] int = result[rank2 + 1..,..];
writeln("###############");
writeln("Projection1:");
printmatrix(proj);

// proj = matmulreduce([L2,ker1])[rank2:,:]
// proj = matmulreduce([L2inv[:,rank2:],proj]).transpose()

var L2invKernel = new list(unmanaged Matrix2D?, true);

// var nr2 = L2invF.domain.high(2) - rank2;
var _L2inv = new unmanaged Matrix2D(L2invF.domain.high(1), nr2);
_L2inv._arr = L2invF[..,rank2 + 1..];
L2invKernel.append(_L2inv);

var _proj = new unmanaged Matrix2D(proj.domain.high(1), proj.domain.high(2));
_proj._arr = proj;
L2invKernel.append(_proj);

var proj2 = matmulreduce(L2invKernel);

writeln("###############");
writeln("Projection2:");
printmatrix(proj2);

t.stop();
writeln("Homology computed in ", t.elapsed(), "s");


proc reducedRowEchelonForm(b) {
  var dims = b.domain.high;
  var dimL = dims(1);
  var dimR = dims(2);
  var minDim = if dimL <= dimR then dimL else dimR;
 
  // writeln(dimL : string ); // dims give me the index set but I need the max value of the index set
  // writeln(minDim);


  var S  = b;
  var IL = IdentityMatrix(dimL);

  var Linv = new list(unmanaged Matrix2D?, true); // listOfMatrixTransformation

  var Linit = new unmanaged Matrix2D(IL.domain.high(1), IL.domain.high(2));
  Linit._arr = IL;
  Linv.append(Linit);

  var L = IL;

  /* writeln("###############"); */
  /* writeln("L:"); */
  /* printmatrix(L); */
  /* writeln("###############"); */
  /* writeln("R:"); */
  /* printmatrix(R); */

  // var rc = _get_next_pivot(b, 3);
  // writeln(rc : string);

  var s2 : int = 1;
  writeln("########");
  for s1 in 1..dimL {
    writeln("Iteration: " +  s1 : string);
    var rdx : int, cdx : int;
    for s2 in s2..dimR {
      var pivot = _get_next_pivot(S,s1, s2);
      if (pivot(1) != -1 && pivot(2) != -1) {
	(rdx, cdx) = pivot;
	s2 = cdx;
	break;
      }
    }
    // Swap rows
    if (rdx > s1) {
      S = swap_rows(s1, rdx, S);
      L = swap_rows(s1, rdx, L);
      var tmp = swap_rows(s1, rdx, IL);
      var LM = new unmanaged Matrix2D(tmp.domain.high(1), tmp.domain.high(2));
      LM._arr = tmp;
      Linv.append(LM);
    }

    var row_indices = [idx in 1..dimL] if (idx != s1 && S(idx,cdx) == 1) then idx;
    // compilerWarning(row_indices.type : string);

    for idx in row_indices {
      // writeln("rdx: " + rdx : string);
      S = add_to_row(S, idx, s1);
      L = add_to_row(L, idx, s1);
      var tmp = add_to_row(IL, idx, s1);
      var LM = new unmanaged Matrix2D(tmp.domain.high(1), tmp.domain.high(2));
      LM._arr = tmp;
      Linv.append(LM);
    }
  }

  var LinvF = matmulreduce(Linv);
  return (L,S,LinvF);
}