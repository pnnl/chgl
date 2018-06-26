/*
  Need to perform termination detection...

  var startedTasks : [] atomic int;
  var finishedTasks : [] atomic int;
  
  Where both are distributed across all locales specified...
  Need privatization so that the object can be used appropriately.
  Potential usage could be...

  proc visit(n : node, term : TerminationDetection, ourParent : locale) {
    var theirParent = here;
    doSomethingTo(n.data);
    
    // Increments startedTasks for 'here'
    term.start(2);
    begin on n.left {
      visit(n.left, term, theirParent);
    }
    begin on n.right {
      visit(n.right, term, theirParent);
    }

    // Increment finishedTasks for 'ourParent'
    term.finish(ourParent);
  }
*/

module TerminationDetection {
  /*
    Termination detector.
  */
  record TerminationDetector {
    var instance;
    var pid = -1;
    
    proc init() {
      instance = new TerminationDetectorImpl();
      pid = instance.pid;
    }

    proc _value {
      if pid == -1 then halt("TerminationDetector is uninitialized...");
      return chpl_getPrivatizedClass(instance.type, pid);
    }

    forwarding _value;
  }

  class TerminationDetectorImpl {
    
    var pid = -1;

    proc init() {
      complete();
      this.pid = _newPrivatizedClass(this);
    }

    proc init(other, pid) {
      this.pid = pid;
    }

    proc dsiPrivatize(pid) {
      return new TerminationDetectorImpl(this, pid);
    }

    proc dsiGetPrivatizedData() {
      return pid;
    }

    inline proc getPrivatizedInstance() {
      return chpl_getPrivatizedCopy(this.type, pid);
    }
  }

}
