use RangeChunk;
use WorkQueue;
use BlockDist;
use Vectors;
use Utilities;
use Time;

config const dataset = "../data/karate.mtx_csr.bin";
config const numEdgesPresent = true;

record Array {
  type eltType;
  var dom = {0..-1};
  var arr : [dom] eltType;
}

beginProfile("TriangleCounting-Naive-Profile");
try! {
  var f = open(dataset, iomode.r, style = new iostyle(binary=1));   
  var reader = f.reader();
  var timer = new Timer();
  timer.start();

  // Read in |V| and |E|
  var numVertices : uint(64);
  var numEdges : uint(64);
  reader.read(numVertices);
  debug("|V| = " + numVertices);
  if numEdgesPresent {
    reader.read(numEdges);
    debug("|E| = " + numEdges);
  }
  reader.close();
  f.close();
  
  var D = {0..#numVertices} dmapped Block(boundingBox={0..#numVertices});
  var A : [D] unmanaged Vector(int);
  
  // On each node, independently process the file and offsets...
  coforall loc in Locales do on loc {
    var f = open(dataset, iomode.r, style = new iostyle(binary=1));    
    // Obtain offset for indices that are local to each node...
    var dom = D.localSubdomain();
    coforall chunk in chunks(dom.low..dom.high by dom.stride, here.maxTaskPar) {
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
        var vec = new unmanaged VectorImpl(int, {0..#(endOffset - beginOffset + 1)});
        reader.readBytes(c_ptrTo(vec.arr[0]), ((endOffset - beginOffset + 1) * 8) : ssize_t);
        vec.sz = (endOffset - beginOffset + 1) : int;
        vec.sort();
        A[idx] = vec;
        reader.revert();
      }
    }
  }
  timer.stop();
  writeln("Initialized Graph in ", timer.elapsed(), "s");
  timer.clear();
  timer.start();
  var numTriangles : int;
  forall v in A.domain with (+ reduce numTriangles) {
    for u in A[v] do if v > u {
      numTriangles += A[v].intersectionSize(A[u]);
    }
  }
  timer.stop();
  writeln("|V| = ", numVertices, ", |E| = ", numEdges, ", numTriangles = ", numTriangles / 3, ", in ", timer.elapsed(), "s");
  f.close();
}
endProfile();
