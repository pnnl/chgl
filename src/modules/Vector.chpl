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
  proc these() : eltType {halt();}
}

class VectorImpl : Vector {
  const growthRate;
  var dom;
  var arr : [dom] eltType;
  var size : int;
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
    if size == cap {
      var oldCap = cap;
      cap = round(cap * growthRate) : int;
      if oldCap == cap then cap += 1;
      this.dom = {0..#cap};
    }
    
    this.arr[size] = elt;
    size += 1;
  }

  override proc this(idx : integral) ref {
    return arr[idx];
  }
}

