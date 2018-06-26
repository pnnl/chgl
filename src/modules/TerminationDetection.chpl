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
    var tasksStarted : atomic int;
    var tasksFinished : atomic int;
    var pid = -1;

    proc init() {
      complete();
      this.pid = _newPrivatizedClass(this);
    }

    proc init(other, pid) {
      this.pid = pid;
    }
      
    inline proc started(n = 1) {
      var ret = tasksStarted.fetchAdd(n);
      assert(ret >= 0 && ret + n >= 0, "tasksStarted overflowed in 'started': (", ret, " -> ", ret + n, ")");
    }

    inline proc finished(n = 1) {
      var ret = tasksFinished.fetchAdd(n);
      assert(ret >= 0 && ret + n >= 0, "tasksFinished overflowed in 'finished': (", ret, " -> ", ret + n, ")");
    }

    proc isFinished() : bool {
      // Check local first...
      if tasksStarted.read() != tasksFinishes.read() {
        return false;
      }
      
      // Check globally...
      var notFinished : atomic bool;
      coforall loc in Locales do on loc {
        const _this = getPrivatizedInstance();
        if _this.tasksStarted.read() != _this.tasksFinished.read() {
          notFinished.write(true);
        }
      }
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
