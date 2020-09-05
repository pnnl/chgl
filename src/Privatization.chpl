use BlockDist;
use Time;

pragma "always RVF"
record Privatized {
  type varType;
  var instance : unmanaged PrivatizedImpl(varType);
  var pid : int;

  proc init(type varType) {
    this.varType = varType;
    this.instance = new unmanaged PrivatizedImpl(varType);
    this.pid = this.instance.pid;
  }

  proc destroy() {
    coforall loc in Locales do on loc {
      delete _value;
    }
  }

  proc _value {
    return chpl_getPrivatizedCopy(instance.type, pid);
  }

  proc readWriteThis(f) { f <~> instance; }

  forwarding _value;
}

proc =(x : Privatized(?eltType), y : eltType) {
  x._value.broadcast[here.id] = y;
}

proc +(x : Privatized(?eltType), y : eltType) {
  return x._value.broadcast[here.id] + y;
}

proc -(x : Privatized(?eltType), y : eltType) {
  return x._value.broadcast[here.id] - y;
}

proc +=(x : Privatized(?eltType), y : eltType) {
  x._value.broadcast[here.id] += y;
}

proc -=(x : Privatized(?eltType), y : eltType) {
  x._value.broadcast[here.id] -= y;
}

proc *(x : Privatized(?eltType), y : eltType) {
  return x._value.broadcast[here.id] * y;
}

proc *=(x : Privatized(?eltType), y : eltType) {
  x._value.broadcast[here.id] *= y;
}

class PrivatizedArray {
  type varType;
  var dom = LocaleSpace dmapped Block(boundingBox=LocaleSpace);
  var arr : [dom] varType;
}

class PrivatizedImpl {
  type varType;
  var pid : int;
  var privatizedArray : unmanaged PrivatizedArray(varType);
  var broadcast = _newArray(privatizedArray.arr._value);

  // Master instance creates a cyclic array over locale space, ensuring that each locale has its own variable.
  proc init(type varType) {
    this.varType = varType;
    this.privatizedArray = new unmanaged PrivatizedArray(varType);
    this.complete();
    this.broadcast._unowned = true;
    this.pid = _newPrivatizedClass(this);
  }
  
  // Initialize the 'clone' slave instance
  proc init(type varType, other, privatizedData) { 
    this.varType = varType; 
    this.privatizedArray = privatizedData[0];
    this.complete();
    this.broadcast._unowned = true;
    this.pid = privatizedData[1]; 
  }
  
  proc dsiPrivatize(privatizedData) { return new unmanaged PrivatizedImpl(varType, this, privatizedData); }
  proc dsiGetPrivatizeData() { return (this.privatizedArray, this.pid); }
  proc readWriteThis(f) { f <~> broadcast[here.id]; }

  proc get(loc : locale = here) ref {
    return get(loc.id);
  }

  proc get(locid : int) ref {
    return broadcast[locid];
  }

  proc deinit() {
    if privatizedArray.locale == here {
      delete privatizedArray;
    }
  }

  forwarding broadcast[here.id];
}