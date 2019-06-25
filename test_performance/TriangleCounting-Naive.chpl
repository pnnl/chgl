use RangeChunk;
use CyclicDist;
use Time;
use Sort;

config const dataset = "../data/karate.mtx_csr.bin";
config const numEdgesPresent = true;

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

record Array {
  type eltType;
  var dom = {0..-1};
  var arr : [dom] eltType;
}

try! {
  var f = open(dataset, iomode.r, style = new iostyle(binary=1));   
  var reader = f.reader();
  var timer = new Timer();
  timer.start();

  // Read in |V| and |E|
  var numVertices : uint(64);
  var numEdges : uint(64);
  reader.read(numVertices);
  writeln("|V| = " + numVertices);
  if numEdgesPresent {
    reader.read(numEdges);
    writeln("|E| = " + numEdges);
  }
  reader.close();
  f.close();
  
  var D = {0..#numVertices} dmapped Cyclic(startIdx=0);
  var A : [D] Array(int);
  
  // On each node, independently process the file and offsets...
  coforall loc in Locales do on loc {
    var f = open(dataset, iomode.r, style = new iostyle(binary=1));    
    // Obtain offset for indices that are local to each node...
    var dom = D.localSubdomain();
    coforall chunk in chunks(dom.low..dom.high by dom.stride align dom.alignment, here.maxTaskPar) {
      var reader = f.reader(locking=false);
      for idx in chunk {
        reader.mark();
        // Open file again and skip to portion of file we want...
        const headerOffset = if numEdgesPresent then 16 else 8;
        reader.advance(headerOffset + idx * 8);

        // Read our beginning and ending offset... since the ending is the next
        // offset minus one, we can just read it from the file and avoid
        // unnecessary communication with other nodes.
        var beginOffset : uint(64);
        var endOffset : uint(64);
        reader.read(beginOffset);
        reader.read(endOffset);
        endOffset -= 1;

        // Advance to current idx's offset...
        var skip = ((numVertices - idx:uint - 1:uint) + beginOffset) * 8;
        reader.advance(skip:int);

        // Pre-allocate buffer for vector and read directly into it
        A[idx].dom = {0..#(endOffset - beginOffset + 1)};
        reader.readBytes(c_ptrTo(A[idx].arr[0]), ((endOffset - beginOffset + 1) * 8) : ssize_t);
        sort(A[idx].arr);
        reader.revert();
      }
    }
  }
  timer.stop();
  writeln("Initialized Graph in ", timer.elapsed(), "s");
  timer.clear();
  timer.start();
  var numTriangles : int;
  coforall loc in Locales with (+ reduce numTriangles) do on loc {
    coforall tid in 0..#here.maxTaskPar with (+ reduce numTriangles) {
      const localSubdomain = A.localSubdomain();
      var _dom = localSubdomain by here.maxTaskPar align (localSubdomain.stride * tid + localSubdomain.alignment);
      for v in _dom  {
        for u in A[v].arr do if v < u {
          numTriangles += intersectionSize(A[v].arr, A[u].arr);
        }
      }
    }
  }
  timer.stop();
  writeln("|V| = ", numVertices, ", |E| = ", numEdges, ", numTriangles = ", numTriangles / 3, ", in ", timer.elapsed(), "s");
  f.close();
}
