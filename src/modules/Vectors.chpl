use CyclicDist;
use BlockDist;

config param VectorGrowthRate : real = 1.5;

// Interface for a resizable array that acts as a vector
class Vector {
  type eltType;
  var _dummy : eltType;

  proc init(type eltType) {
    this.eltType = eltType;
  }
  proc append(elt : eltType) {halt();}
  proc this(idx : integral) ref { 
    return _dummy;
  }

  iter these(param tag : iterKind) where tag == iterKind.standalone {
    halt();
  }

  proc size() return 0;
  iter these() : eltType {halt();}
  proc clear() {halt();}
}

class VectorImpl : Vector {
  const growthRate;
  var dom;
  var arr : [dom] eltType;
  var sz : int;
  var cap : int;
  
  proc init(type eltType, dom, growthRate = VectorGrowthRate) {
    super.init(eltType);
    this.growthRate = growthRate;
    this.dom = dom; 
    assert(this.dom.low == 0 && this.dom.stride == 1, "Vector cannot use strided domains nor domains that do not begin at 0");
    this.complete();
    this.cap = dom.size;
  }

  override proc append(elt : eltType) {
    if sz == cap {
      var oldCap = cap;
      cap = round(cap * growthRate) : int;
      if oldCap == cap then cap += 1;
      this.dom = {0..#cap};
    }
    
    this.arr[sz] = elt;
    sz += 1;
  }

  override proc this(idx : integral) ref {
    assert(idx < sz && idx >= dom.low, "Index ", idx, " is out of bounds of ", dom.low..#sz);
    return arr[idx];
  }

  override iter these() ref {
    for a in arr[dom.low..#sz] do yield a;
  }

  override iter these(param tag : iterKind) where tag == iterKind.standalone {
    forall a in arr[dom.low..#sz] do yield a;
  }

  override proc size() return sz;

  override proc clear() {
    this.sz = dom.low;
  }

  proc readWriteThis(f) {
    f <~> arr;
  }
}

