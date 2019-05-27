module EquivalenceClasses {
  use Vectors;
  
  class Equivalence {
    type keyType;
    type cmpType;
    var eqclassesDom : domain(cmpType);
    var eqclasses : [eqclassesDom] keyType;
    var candidatesDom : domain(keyType);
    var candidates : [candidatesDom] unmanaged Vector(keyType);
    var keyToCmp : func(keyType, cmpType);

    proc init(type keyType) {
      this.keyType = keyType;
      this.cmpType = keyType;
      this.keyToCmp = lambda(x : keyType) : keyType { return x; };
    }

    proc init(type keyType, type cmpType, keyToCmp : func(keyType, cmpType)) {
      this.keyType = keyType;
      this.cmpType = cmpType;
      this.keyToCmp = keyToCmp;
    }

    proc init(type keyType, keyToCmp) {
      this.keyType = keyType;
      this.cmpType = keyToCmp.retType;
      this.keyToCmp = keyToCmp;
    }

    proc add(key : keyType) {
      var x = keyToCmp(key);
      if eqclassesDom.contains(x) {
        var y = eqclasses[x];
        candidates[y].append(key);
      } else {
        this.eqclassesDom += x;
        eqclasses[x] = key;
        this.candidatesDom += key;
        candidates[key] = new unmanaged VectorImpl(keyType, {0..-1});
      }
    }

    proc add(other : this.type) {
      for key in other.eqclassesDom {
        if this.eqclassesDom.contains(key) {
          var newKey = this.eqclasses[key];
          this.candidates[newKey].append(key);
          this.candidates[newKey].append(other.candidates[key].getArray());
        } else {
          this.eqclassesDom += key;
          this.eqclasses[key] = key;
          this.candidatesDom += key;
          var arr = other.candidates[key].getArray();
          var dom = arr.domain;
          this.candidates[key] = new unmanaged VectorImpl(keyType, dom);
          this.candidates[key].append(arr);
        }
      }
    }

    proc readWriteThis(f) {
      f <~> "Equivalence Classes:";
      for (key, value) in zip(eqclassesDom, eqclasses) {
        f <~> " " <~> key <~> " -> [" <~> value <~> "] " <~> candidates[value];
      }
    }
  }

  class ReduceEQClass : ReduceScanOp {
    type keyType;
    type cmpType;
    var value : Equivalence(keyType, cmpType);

    proc identity return new Equivalence(keyType, cmpType);
    proc accumulate(x) {
      value.add(x);
    }
    proc accumulateOntoState(ref state, x) {
      state.add(x);
    }
    proc combine(x) {
      value.add(x.value);
    }
    proc generate() return value;
    proc clone() return new unmanaged ReduceEqClass(keyType, cmpType);
  }

  proc main() {
    var eqclass = new Equivalence(int, lambda(x : int) { return x % 2 == 0; });
    for i in 1..10 do eqclass.add(i);
    writeln(eqclass);
  }
}
