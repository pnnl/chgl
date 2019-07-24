use CyclicDist;
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

class PrivatizedImpl {
  type varType;
  var dom = LocaleSpace dmapped Cyclic(startIdx=0);
  var arr : [dom] varType;
  var pid : int;
  var arrPid = arr._pid;
  var arrInstance = arr._value;
  pragma "no copy"
  var broadcast = _newArray(arrInstance);

  // Master instance creates a cyclic array over locale space, ensuring that each locale has its own variable.
  proc init(type varType) {
    this.varType = varType;
    this.dom = LocaleSpace dmapped Cyclic(startIdx=0);
    this.complete();
    this.broadcast._unowned = true;
    this.pid = _newPrivatizedClass(this);
  }
  
  // Initialize the 'clone' slave instance
  proc init(type varType, other, privatizedData) { 
    this.varType = varType; 
    // Need to clear cyclic domain so that it does not attempt to create a distributed array.
    var dom = other.dom;
    dom.clear();
    this.dom = dom;

    // Get a reference to the master instance's distributed array
    this.arrPid = privatizedData[1];
    this.arrInstance = chpl_getPrivatizedCopy(arr._instance.type, this.arrPid);
    
    // Privatize
    this.complete();
    this.broadcast._unowned = true;
    this.pid = privatizedData[2]; 
  }
  
  proc dsiPrivatize(privatizedData) { return new unmanaged PrivatizedImpl(varType, this, privatizedData); }
  proc dsiGetPrivatizeData() { return (this.arr._pid, pid); }
  proc readWriteThis(f) { f <~> broadcast[here.id]; }

  proc onLocale(loc : locale) ref {
    return onLocale(loc.id);
  }

  proc onLocale(locid : int) ref {
    return broadcast[locid];
  }

  forwarding broadcast[here.id];
}