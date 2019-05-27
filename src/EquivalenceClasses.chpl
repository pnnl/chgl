module EquivalenceClasses {
  use Vectors;
  
  class Equivalence {
    type keyType;
    type cmpType;
    var eqclassesDom : domain(cmpType);
    var eqclasses : [eqclassesDom] keyType;
    var candidatesDom : domain(keyType);
    var candidates : [candidatesDom] domain(keyType);
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
        candidates[y] += key;
      } else {
        this.eqclassesDom += x;
        eqclasses[x] = key;
        this.candidatesDom += key;
      }
    }

    proc add(other : this.type) {
      for (key, value) in zip(other.eqclassesDom, other.eqclasses) {
        if this.eqclassesDom.contains(key) {
          var newKey = this.eqclasses[key];
          this.candidates[newKey] += value;
          this.candidates[newKey] += other.candidates[value];
        } else {
          this.eqclassesDom += key;
          this.eqclasses[key] = value;
          this.candidatesDom += value;
          this.candidates[value] += other.candidates[value];
        }
      }
    }

    proc reduction() {
      return new unmanaged ReduceEQClass(this:unmanaged);
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
    var value : unmanaged Equivalence(keyType, cmpType);

    proc init(eq : unmanaged Equivalence(?keyType, ?cmpType)) {
      this.keyType = keyType;
      this.cmpType = cmpType;
      this.value = eq;
    }

    proc init(type keyType, type cmpType, keyToCmp) {
      this.keyType = keyType;
      this.cmpType = cmpType;
      this.value = new unmanaged Equivalence(keyType, cmpType, keyToCmp);
    }

    proc identity return new unmanaged Equivalence(keyType, cmpType, value.keyToCmp);
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
    proc clone() return new unmanaged ReduceEQClass(keyType, cmpType, value.keyToCmp);
  }

  proc main() {
    var eqclass = new Equivalence(int, lambda(x : int) { return x % 2 == 0; });
    for i in 1..10 do eqclass.add(i);
    var redux = eqclass.reduction();
    forall i in 11..100 with (redux reduce eqclass) {
      eqclass.add(i);
    }

    writeln(eqclass);
  }
}
