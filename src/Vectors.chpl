use CyclicDist;
use BlockDist;
use Sort;
use Utilities;

config param VectorGrowthRate : real = 1.5;

// Interface for a resizable array that acts as a vector
class Vector {
  type eltType;
  var _dummy : eltType;

  proc init(type eltType) {
    this.eltType = eltType;
  }
  proc append(elt : eltType) {halt();}
  proc append(elts : [] eltType) { halt(); }
  proc append(ir : _iteratorRecord) { halt(); }
  proc sort() {halt();}
  proc this(idx : integral) ref { 
    return _dummy;
  }

  iter these(param tag : iterKind) ref : eltType where tag == iterKind.standalone {
    halt();
  }

  proc size() return 0;
  iter these() ref : eltType {halt();}
  proc getArray() { var arr : [0..-1] eltType; halt(); return arr; }
  proc clear() {halt();}
  proc intersection(other : Vector(eltType)) : Vector(eltType) { halt(); }
  proc intersectionSize(other : Vector(eltType)) : int { halt(); }
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
  
  override proc intersection(other : Vector(eltType)) : Vector(eltType) {
    var _other = other : this.type;
    ref arr1 = this.arr[this.dom.low..#this.sz];
    if other.locale != here {
      var arr2 = _other.arr[_other.dom.low..#_other.sz];
      var newArr = Utilities.intersection(arr1, arr2);
      const newDom = newArr.domain;
      var ret = new VectorImpl(eltType, newDom);
      ret.arr = newArr;
      return ret;
    } else {
      ref arr2 = _other.arr[_other.dom.low..#_other.sz];
      var newArr = Utilities.intersection(arr1, arr2);
      const newDom = newArr.domain;
      var ret = new VectorImpl(eltType, newDom);
      ret.arr = newArr;
      return ret;
    }
  }
  
  override proc intersectionSize(other : Vector(eltType)) : int {
    var _other = other : this.type;
    ref arr1 = this.arr[this.dom.low..#this.sz];
    if other.locale != here {
      var arr2 = _other.arr[_other.dom.low..#_other.sz];
      return Utilities.intersectionSize(arr1, arr2);
    } else {
      ref arr2 = _other.arr[_other.dom.low..#_other.sz];
      return Utilities.intersectionSize(arr1, arr2);
    }  
  }

  override proc append(elts : [] eltType) {
    if sz + elts.size >= cap {
      cap = sz + elts.size;
      this.dom = {0..#cap};
    }

    this.arr[sz..#elts.size] = elts;
    sz += elts.size;
  }
  
  override proc append(ir : _iteratorRecord) {
    if iteratorToArrayElementType(ir.type) != eltType {
      compilerError(
          "Attempt to append an iterable expression of type '", 
          iteratorToArrayElementType(ir.type) : string, "' when need type '", 
          eltType : string, "'"
      );
    }

    for elt in ir do append(elt);
  }

  override proc sort() {
    Sort.sort(arr[dom.low..#sz]);
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

  override proc getArray() {
    return  arr[dom.low..#sz];
  }

  proc readWriteThis(f) {
    f <~> "{" <~> getArray() <~> "}";
  }
}

