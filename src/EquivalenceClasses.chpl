module EquivalenceClasses {
  use Vectors;
  
  class Equivalence {
    type keyType;
    type cmpType;
    var eqclassesDom : domain(cmpType);
    var eqclasses : [eqclassesDom] keyType;
    var candidatesDom : domain(keyType);
    var candidates : [candidatesDom] domain(keyType);

    proc init(type keyType) {
      this.keyType = keyType;
      this.cmpType = keyType;
    }

    proc init(type keyType, type cmpType) {
      this.keyType = keyType;
      this.cmpType = cmpType;
    }

    iter getEquivalenceClasses() : keyType {
      for key in eqclasses do yield key;
    }

    iter getEquivalenceClasses(param tag : iterKind) : keyType where tag == iterKind.standalone {
      forall key in eqclasses do yield key;
    }

    iter getCandidates(key : keyType) : keyType {
      for candidate in candidates[key] {
        yield candidate;
      }
    }

    iter getCandidates(key : keyType, param tag : iterKind) : keyType where tag == iterKind.standalone {
      forall candidate in candidates[key] {
        yield candidate;
      }
    }

    proc add(key : keyType) {
      add(key, key);
    }

    proc add(key : keyType, x : cmpType) {
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

    proc init(type keyType, type cmpType) {
      this.keyType = keyType;
      this.cmpType = cmpType;
      this.value = new unmanaged Equivalence(keyType, cmpType);
    }

    proc identity return new unmanaged Equivalence(keyType, cmpType);
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
    proc clone() return new unmanaged ReduceEQClass(keyType, cmpType);
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
