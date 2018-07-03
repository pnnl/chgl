use FIFOChannel;
use List;

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
  proc consume(fn) : void {
    do {
      var buf = inchan.recv();
      forall b in buf do fn(b);
    } while !inchan.isClosed();

    // See if anything can be processed after close
    var buf = inchan.recv();
    forall b in buf do fn(b);
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
   
  // Should return a tuple (tag, elt)
  proc groupBy(fn, type tagType) {
    var outStream = new Stream((tagType, list(tagType)));
    begin {
      var dictDom : domain(tagType);
      var dict : [dictDom] list(eltType); 
      do {
        var buf = inchan.recv();
        for b in buf {
          var (t, elt) = fn(b);
          dictDom += t;
          dict[t].push_back(elt);
        }
      } while !inchan.isClosed();
      
      // Send grouped list of data
      for t in dictDom {
        const toSend = (t, dict[t]);
        outStream.outchan.send(toSend);
      }
      outStream.outchan.close();
    }

    return outStream;
  }
}


proc main() {
  proc addOne(x : int) return x + 1;
  proc lessThan1000(x : int) return x < 1000;
  proc countOccurences((isEven, values) : (int, list(int))) { 
    writeln("There are ", values.size, " values that are ", if isEven then "even" else "odd"); 
  }
  proc parity(x : int) return (x % 2, x);
  var str = new Stream({1..1024});
  str.map(addOne).filter(lessThan1000).groupBy(parity, int).consume(countOccurences);
}
