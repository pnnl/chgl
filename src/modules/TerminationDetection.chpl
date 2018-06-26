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
  
    // Wait for the termination of all tasks
    proc wait() {
      var state = 0;
      var started = 0;
      var finished = 0;

      while true {
        select state {
          // Check if all counters add up to 0.
          when 0 {
            coforall loc in Locales do on loc with (+ reduce started, + reduce finished) {
              const _this = getPrivatizedInstance();
              started += _this.tasksStarted.read();
              finished += _this.tasksFinished.read();
            }

            // Check if all started tasks have finished
            if started == finished {
              state = 1;
            } else {
              chpl_task_yield();
            }
          }
          // Check if all counters add up to what we had before...
          when 1 {
            var newStarted = 0;
            var newFinished = 0;
            coforall loc in Locales do on loc with (+ reduce newStarted, + reduce newFinished) {
              const _this = getPrivatizedInstance();
              newStarted += _this.tasksStarted.read();
              newFinished += _this.tasksFinished.read();
            }

            // Check if finished...
            if newStarted == newFinished {
              // Check if no changes since last check...
              if newStarted == started && newFinished == finished {
                // No change, termination of all tasks detected...
                return;
              } else {
                // Update started and finished tasks and try again...
                started = newStarted;
                finished = newFinished;
                chpl_task_yield();
              }
            } else {
              // Not finished...
              state = 0;
              chpl_task_yield();
            }
          }
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
