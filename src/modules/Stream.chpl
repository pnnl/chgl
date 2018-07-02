use FIFOChannel;

class Stream {
  type eltType;
  var inchan : Channel(eltType);
  var outchan : Channel(eltType);
  
  proc init(type eltType, chunkSize = 1024) {
    this.eltType = eltType;
    this.inchan = new Channel(this.eltType, 0);
    this.outchan = new Channel(this.eltType, chunkSize);
    inchan.pair(outchan);
  }

  proc init(elts : ?eltType ...?n) {
    this.eltType = eltType[1];
    this.inchan = new Channel(this.eltType, 0);
    this.outchan = new Channel(this.eltType, n);
    inchan.pair(outchan);

    complete();
    
    for elt in elts do outchan.send(elt);
    outchan.close();
  }
  
  // TODO: Does Chapel consume all elements in the array?
  proc init(iterable, chunkSize = 1024) where !isTupleType(iterable.type) {
    this.eltType = iteratorToArrayElementType(iterable.these().type);
    this.inchan = new Channel(eltType, 0);
    this.outchan = new Channel(eltType, chunkSize);
    inchan.pair(outchan);

    complete();

    //Spawn feeder task...
    begin {
      for elt in iterable do this.outchan.send(elt);
      outchan.close();
    }
  }
  
  // Terminal operation, processes rest of stream...
  proc consume(fn) {
    do {
      var buf = inchan.recv();
      forall b in buf do fn(b);
    } while !inchan.isClosed();
  }
  
  // TODO: Fix when Chapel lets you query type of first class function...
  proc map(fn, type outType = eltType) {
    var outStream = new Stream(outType);
    begin {
      do {
        var buf = inchan.recv();
        forall b in buf do outStream.outchan.send(fn(b));
      } while !inchan.isClosed();
      outStream.outchan.close();
    }
    return outStream;
  }

  proc filter(fn) {
    var outStream = new Stream(eltType);
    begin {
      do {
        var buf = inchan.recv();
        forall b in buf do if fn(b) then outStream.outchan.send(b);
      } while !inchan.isClosed();
      outStream.outchan.close();
    }
    return outStream;
  }
}

proc main() {
  //var a = new Stream(1);
  var b = new Stream({1..1024});
  b.map(lambda (x : int) : int {
        return x * 2;
      }).filter(lambda (x : int) : bool {
        return x < 1000;
      }).consume(lambda (x : int) { 
        writeln(x);
      });
  //var c = new Stream(arr);

}
