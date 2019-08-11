use RangeChunk;
use CyclicDist;
use Time;
use Sort;
use CommDiagnostics;

config const dataset = "../data/ca-GrQc.mtx_csr.bin";
config const numEdgesPresent = true;
config const printTiming = true;
config const isOptimized = false;
config const arrayGrowthRate = 1.5;
config const aggregationThreshold = 64 * 1024;
config const debugTC = false;

iter roundRobin(dom) {

}

iter roundRobin(dom, param tag : iterKind) ref where tag == iterKind.standalone {
  coforall loc in Locales do on loc {
    coforall tid in 0..#here.maxTaskPar {
      const localSubdomain = dom.localSubdomain();
      var _dom = localSubdomain by here.maxTaskPar align (localSubdomain.stride * tid + localSubdomain.alignment);
      for v in _dom do yield v;
    }
  }
}

proc isLocalArray(A : []) : bool {
  return A.locale == here && A._value.dom.locale == here;
}

/*
  Obtains the intersection size of two arrays, A and B. This method is optimized for
  locality and will copy any remote arrays to be entirely local; this includes
  a locality check for the array and the domain itself (which will be remote if
  the user creates an implicit copy).
*/
proc intersectionSize(A : [] ?t, B : [] t) {
  if isLocalArray(A) && isLocalArray(B) {
    return _intersectionSize(A, B);
  } else if isLocalArray(A) && !isLocalArray(B) {
    const _BD = B.domain; // Make by-value copy so domain is not remote.
    var _B : [_BD] t = B;
    return _intersectionSize(A, _B);
  } else if !isLocalArray(A) && isLocalArray(B) {
    const _AD = A.domain; // Make by-value copy so domain is not remote.
    var _A : [_AD] t = A;
    return _intersectionSize(_A, B);
  } else {
    const _AD = A.domain; // Make by-value copy so domain is not remote.
    const _BD = B.domain;
    var _A : [_AD] t = A;
    var _B : [_BD] t = B;
    return _intersectionSize(_A, _B);
  }
}

pragma "no doc"
proc _intersectionSize(A : [] ?t, B : [] t) {
  var match : int;
  local {
    var idxA = A.domain.low;
    var idxB = B.domain.low;
    while idxA <= A.domain.high && idxB <= B.domain.high {
      const a = A[idxA];
      const b = B[idxB];
      if a == b { 
        match += 1;
        idxA += 1; 
        idxB += 1; 
      }
      else if a > b { 
        idxB += 1;
      } else { 
        idxA += 1;
      }
    }
  }
  return match;
}

pragma "default intent is ref"
record Array {
  type eltType;
  var dom = {0..0};
  var arr : [dom] eltType;
  var sz : int;
  var cap : int = 1;

  iter these() {
    if sz != 0 {
      if this.locale != here {
        var _dom = {0..#sz};
        var _arr : [_dom] eltType = arr;
        for a in arr[0..#sz] do yield a;
      } else {
        for a in arr[0..#sz] do yield a;
      }
    }
  }

  iter these(param tag : iterKind) where tag == iterKind.standalone {
    if sz != 0 then
      if this.locale != here {
        var _dom = {0..#sz};
        var _arr : [_dom] eltType = arr;
        forall a in arr[0..#sz] do yield a;
      } else {
        forall a in arr[0..#sz] do yield a;
      }
  }
  
  proc append(ref other : this.type) {
    const otherSz = other.sz;
    if otherSz == 0 then return;
    local { 
      if sz + otherSz > cap {
        this.cap = sz + otherSz;
        this.dom = {0..#cap};
      }
    }
    this.arr[sz..#otherSz] = other.arr[0..#otherSz];
    sz += otherSz;
  }

  proc append(elt : int) {
    local {
      if sz == cap {
        var oldCap = cap;
        cap = round(cap * arrayGrowthRate) : int;
        if oldCap == cap then cap += 1;
        this.dom = {0..#cap};
      }
    
      this.arr[sz] = elt;
      sz += 1;
    }
  }

  proc this(idx) return arr[idx];

  pragma "no copy return"
  proc getArray() {
    return arr[0..#sz];
  }

  proc clear() {
    local do this.sz = 0;
  }

  proc size return sz;
}

var numVertices : uint(64);
var numEdges : uint(64);

var globalTimer = new Timer();
var timer = new Timer();
globalTimer.start();
timer.start();

try! {
  var f = open(dataset, iomode.r, style = new iostyle(binary=1));   
  var reader = f.reader();
  
  // Read in |V| and |E|
  
  reader.read(numVertices);
  if debugTC then writeln("|V| = " + numVertices);
  if numEdgesPresent {
    reader.read(numEdges);
    if debugTC then writeln("|E| = " + numEdges);
  }
  reader.close();
  f.close();
}

var D = {0..#numVertices} dmapped Cyclic(startIdx=0);
var A : [D] Array(int);

try! {
  // On each node, independently process the file and offsets...
  coforall loc in Locales do on loc {
    var f = open(dataset, iomode.r, style = new iostyle(binary=1));    
    // Obtain offset for indices that are local to each node...
    var dom = D.localSubdomain();
    coforall chunk in chunks(dom.low..dom.high by dom.stride align dom.alignment, here.maxTaskPar) {
      var reader = f.reader(locking=false);
      // Open file again and skip to portion of file we want...
      const headerOffset = if numEdgesPresent then 16 else 8;
      var currentOffset = 0;
      var offsets : [0..-1] (int, int, int);
      var lastEndOffset : int;
      for idx in chunk {
        const newOffset = headerOffset + idx * 8;
        const oldOffset = currentOffset;
        if newOffset > oldOffset {
          reader.advance((headerOffset + idx * 8) - currentOffset);
          currentOffset = headerOffset + idx * 8;
        }
        
        // Read our beginning and ending offset... since the ending is the next
        // offset minus one, we can just read it from the file and avoid
        // unnecessary communication with other nodes.
        var beginOffset : int(64);
        var endOffset : int(64);
        if newOffset > oldOffset {
          reader.read(beginOffset);
        } else {
          beginOffset = lastEndOffset + 1;
        }

        reader.read(endOffset);
        endOffset -= 1;
        offsets.push_back((idx, beginOffset, endOffset));
        currentOffset += 16;
        lastEndOffset = endOffset;
      }

      const baseOffset = headerOffset + (numVertices:int + 1) * 8;
      for (idx, start, end) in offsets {
        // Advance to current idx's offset...
        var skip = (baseOffset + start * 8) - currentOffset;
        assert(skip >= 0, "baseOffset=", baseOffset, " skip=", skip, ", start=", start, ", end=", end, ", currentOffset=", currentOffset);
        reader.advance(skip);
        currentOffset = baseOffset + start * 8;
        const N = end - start + 1;
        const NBytes = N * 8;
        assert(N > 0, "N=", N, ", baseOffset=", baseOffset, " idx= ", idx, ", end=", end, ", start=", start);

        // Pre-allocate buffer for vector and read directly into it
        ref arr = A[idx];
        arr.dom = {0..#N};
        var ptr = c_ptrTo(arr.arr[0]);
        reader.readBytes(ptr, NBytes : ssize_t);
        arr.sz = arr.dom.size;
        arr.cap = arr.dom.size;
        sort(arr.arr);
        currentOffset += NBytes;
      }
    }
    f.close();
  }
}
timer.stop();
if printTiming then writeln("Initialized: ", timer.elapsed());
timer.clear();

timer.start();
// TODO: Have a more complex and aggregated version that sends the array as well as
// requested indices to the locales it needs to communicate with to avoid the need
// to copy.
var numTriangles : int;
if !isOptimized {
  forall v in roundRobin(A) with (+ reduce numTriangles) {
    for u in A[v] do if v < u {
      numTriangles += intersectionSize(A[v].arr, A[u].arr);
    }
  }
} else {
  forall v in roundRobin(A) with (+ reduce numTriangles) {
    if A[v].size < aggregationThreshold || numLocales == 1 {
      for u in A[v] do if v < u {
        numTriangles += intersectionSize(A[v].arr, A[u].arr);
      }
    } else {
      // Aggregate outgoing neighbor intersections
      var work : [LocaleSpace] Array(int);
      for u in A[v] do if v < u {
        work[D.dist.idxToLocale(u).id].append(u);
      }
      coforall loc in Locales with (+ reduce numTriangles) do on loc {
        var ourWork = work[here.id];
        if ourWork.size != 0 {
          var dom = {0..#A[v].size};
          var arr : [dom] int = A[v].getArray();
          for u in ourWork {
            numTriangles += intersectionSize(arr, A[u].arr);
          }
        }
      }
    }
  }
}
timer.stop();
writeln("|V| = ", numVertices, ", |E| = ", numEdges, ", numTriangles = ", numTriangles / 3);
if printTiming then writeln("Time: ", timer.elapsed());