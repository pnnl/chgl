/*
  Provides an abstraction used to efficiently compute equivalence classes. An
  equivalence class is a set where all elements of that set are equivalent to
  each other. The `cmpType` is used to determine the equivalence class associated
  with a `keyType`. For example, if the `keyType` is a hyperedge, the `cmpType`
  is the set of vertices that are incident in it. Each equivalence class has what
  is known as a `candidate`, which is an arbitrarily chosen leader for an equivalence
  class, making it easy to select which `keyType` to keep based on duplicate `cmpType`.
*/
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
    
    /*
      Adds 'key' to an equivalence class, or making it the candidate
      if no current equivalence class exists. 
    */
    proc add(key : keyType, cmp : cmpType) {
      // Make ourselves a follower of the current candidate
      if eqclassesDom.contains(cmp) {
        var candidate = eqclasses[cmp];
        candidates[candidate] += key;
      } else {
        // Make ourselves a candidate
        this.eqclassesDom += cmp;
        eqclasses[cmp] = key;
        this.candidatesDom += key;
      }
    }
    
    /*
      Adds another equivalence class to this one.
    */
    proc add(other : this.type) {
      for (cmp, key) in zip(other.eqclassesDom, other.eqclasses) {
        // We already have one of their candidates, add them as our followers
        if this.eqclassesDom.contains(cmp) {
          var candidate = this.eqclasses[cmp];
          this.candidates[candidate] += key;
          this.candidates[candidate] += other.candidates[key];
        } else {
          // New candidate...
          this.eqclassesDom += cmp;
          this.eqclasses[cmp] = key;
          this.candidatesDom += key;
          this.candidates[key] += other.candidates[key];
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
