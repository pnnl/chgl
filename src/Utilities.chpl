use CyclicDist;
use BlockDist;
use Random;
use Futures;
use CommDiagnostics;
use VisualDebug;
use Memory;

config const profileCommDiagnostics = false;
config const profileCommDiagnosticsVerbose = false;
config const profileVisualDebug = false;

proc beginProfile(vdebugName = "vdebug") {
  if profileCommDiagnostics {
    startCommDiagnostics();
  }
  if profileCommDiagnosticsVerbose {
    startVerboseComm();
  }
  if profileVisualDebug {
    startVdebug(vdebugName);
  }
}

proc endProfile() {
  if profileCommDiagnosticsVerbose {
    stopVerboseComm();
  }
  if profileCommDiagnostics {
    stopCommDiagnostics();
    for (loc, diag) in zip(Locales, getCommDiagnostics()) {
      writeln(loc, ": ", diag);
    }
  }
  if profileVisualDebug {
    stopVdebug();
  }
}


proc intersection(A : [] ?t, B : [] t) {
  var C : [0..-1] t;
  var idxA = A.domain.low;
  var idxB = B.domain.low;
  while idxA <= A.domain.high && idxB <= B.domain.high {
    const a = A[idxA];
    const b = B[idxB];
    if a == b { 
      C.push_back(a);
      idxA += 1; 
      idxB += 1; 
    }
    else if a > b { 
      idxB += 1;
    } else { 
      idxA += 1;
    }
  }
  return C;
}

proc intersectionSize(A : [] ?t, B : [] t) {
  var idxA = A.domain.low;
  var idxB = B.domain.low;
  var match : int;
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
  return match;
}

extern type chpl_comm_nb_handle_t;

extern proc chpl_comm_get_nb(
    addr : c_void_ptr, node : chpl_nodeID_t, raddr : c_void_ptr, 
    size : size_t, typeIndex : int(32), commID : int(32), 
    ln : c_int, fn : int(32)
) : chpl_comm_nb_handle_t;

inline proc getAddr(ref x : ?t) : c_void_ptr {
  return __primitive("_wide_get_addr", x);
}

inline proc getLocaleID(ref x : ?t) : chpl_localeID_t {
  return __primitive("_wide_get_locale", x);
}

inline proc getNodeID(ref x : ?t) : chpl_nodeID_t {
  return chpl_nodeFromLocaleID(getLocaleID(x));
}

proc get_nb(ref r1 : ?t1) : Future((t1,)) {
  record FutureCallback1 {
    type _t1;
    var _r1 : _t1; 
    var h1 : chpl_comm_nb_handle_t;

    proc init(type _t1, ref r1 : _t1) {
      this._t1 = _t1;
      // TODO: Find a way to typeIndex
      //chpl_comm_get_nb(getAddr(r1), getNodeID(r1), getAddr(_r1), sizeof(_t1), 
    }

    proc this() {
      // TODO
    }
  }
}


// Random Number Generator utilities...
var _globalIntRandomStream = makeRandomStream(int);
var _globalRealRandomStream = makeRandomStream(real);

proc randInt(low, high) {
  return _globalIntRandomStream.getNext(low, high);
}

proc randInt(high) {
  return randInt(0, high);
}

proc randInt() {
  return randInt(min(int), max(int));
}

proc randReal(low, high) {
  return _globalRealRandomStream.getNext(low, high);
}

proc randReal(high) {
  return randReal(0, high);
}

proc randReal() {
  return randReal(0, 1);
}

// Utilize the fact that a 'class' in Chapel is a heap-allocated object, and all
// remote accesses will have to go through the host first, hence making it centralized.
class Centralized {
  var x;
  proc init(x) {
    this.x = x;
  }

  proc init(type X) {
    this.x = new X();
  }

  forwarding x;
}

inline proc getLocale(dom, idx) {
  var loc = dom.dist.idxToLocale(idx);
  var locID = chpl_nodeFromLocaleID(__primitive("_wide_get_locale", loc));
  
  // Handles cases where we get a locale that is allocated on another locale...
  if locID == here.id then return loc;
  else return Locales[locID];
}

inline proc getLocale(arr : [], idx) {
  return getLocale(arr.domain, idx);
}

inline proc createCyclic(dom : domain) {
  return dom dmapped Cyclic(startIdx=dom.low);
}
inline proc createCyclic(rng : range) {
  return createCyclic({rng});
}
inline proc createCyclic(sz : integral, startIdx = 1) {
  return createCyclic(startIdx..#sz);
}
inline proc createBlock(dom : domain) {
  return dom dmapped Block(dom);
}
inline proc createBlock(rng : range) {
  return createBlock({rng});
}
inline proc createBlock(sz : integral, startIdx = 1) {
  return createBlock(startIdx..#sz);
}

iter getLines(file : string) : string {
  var f = open(file, iomode.r).reader();
  var tmp : string;
  while f.readline(tmp) do yield tmp;
}

iter getLines(file : string, chunkSize = 1024, param tag : iterKind) : string where tag == iterKind.standalone {
  var chunk : atomic int;
  coforall loc in Locales do on loc {
    coforall tid in 1..#here.maxTaskPar {
      proc p() { return open(file, iomode.r).reader(); }
      var f = p();
      var currentIdx = 0;
      var readChunks = true;
      while readChunks {
        // Claim a chunk...
        var ix = chunk.fetchAdd(chunkSize);
        // Skip ahead to chunk we claimed...
        var tmp : string;
        for 1..#(ix - currentIdx) do f.readline(tmp);
        // Begin processing our chunk...
        for 1..#chunkSize {
          if f.readline(tmp) {
            yield tmp;
          } else {
            readChunks = false;
            break;
          }
        }
      }
    }
  }
}

// Iterator Utilities

// Determine if any elements are true...
// any([false, false, true, false, false]) == true
// any([false, false, false, false, false]) == false
proc any(it : _iteratorRecord) {
  for b in it do if b == true then return true;
  return false;
}

proc all(it : _iteratorRecord) {
  for b in it do if b == false then return false;
  return true;
}
