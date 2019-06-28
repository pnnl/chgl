/*
  In termination detection, each time a task spawns another task, the spawning task
  becomes the parent and the spawned task is the child. The parent must increment the
  'tasksStarted' counter each time it creates a child, and the child must increment the
  'tasksFinished' counter before being destroyed. Each locale has its own privatized counters,
  so if the parent and child are not located on the same locale, the increment and decrement 
  occur on the respective locales counters, hence a locale can have a 'tasksStarted' counter that is 
  higher or lower than the 'tasksFinished' counter, even if all tasks have terminated. The benefit
  to having increments being local is the increased locality.

  Determining whether or not all tasks have terminated involves performing multiple distributed
  reductions, which Chapel makes very easy. Spawning a remote task on each node, and using the
  reduce intent is enough to implement a distributed reduction. Once the reduction has been
  performed twice, and if there has been no update, and if both times the reduction of both
  the 'tasksStarted' and 'tasksFinished' are equivalent, no task is alive at that given time. 
  
  Example of its usage::

    proc visit(n : node, term : TerminationDetection) {
      doSomethingTo(n.data);
      
      // About to spawn two tasks...
      term.start(2);
      begin on n.left {
        visit(n.left, term);
      }
      begin on n.right {
        visit(n.right, term);
      }

      // Task just finished...
      term.finish();
    }

*/

module TerminationDetection {
  use Time;
  use Utilities;
  use Random;

  /*
     Termination detector.
     */
  pragma "always RVF"
  record TerminationDetector {
    var instance : unmanaged TerminationDetectorImpl;
    var pid = -1;

    proc init(n = 0) {
      instance = new unmanaged TerminationDetectorImpl(n);
      pid = instance.pid;
    }

    proc _value {
      if pid == -1 then halt("TerminationDetector is uninitialized...");
      return chpl_getPrivatizedCopy(instance.type, pid);
    }

    forwarding _value;
  }

  proc <=>(ref lhs : TerminationDetector, ref rhs : TerminationDetector) {
    lhs.pid <=> rhs.pid;
  }
  
  class TerminationDetectorImpl {
    var tasksStarted : atomic int;
    var tasksFinished : atomic int;
    var pid = -1;

    proc init(n = 0) {
      complete();
      this.tasksStarted.add(n);
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

    proc getStatistics() : (int, int) {
      var started : int;
      var finished : int;
      coforall loc in Locales with (+ reduce started, + reduce finished) do on loc {
        const _this = getPrivatizedInstance();
        started += _this.tasksStarted.read();
        finished += _this.tasksFinished.read();
      }
      return (started, finished);
    }

    proc hasTerminated() : bool {
      var started = 0;
      var finished = 0;
      coforall loc in Locales with (+ reduce started, + reduce finished) do on loc {
        const _this = getPrivatizedInstance();
        started += _this.tasksStarted.read();
        finished += _this.tasksFinished.read();
      }

      // Check if all started tasks have finished
      if started != finished {
        // Not finished...
        return false;
      }
      var newStarted = 0;
      var newFinished = 0;
      for loc in Locales do on loc {
        const _this = getPrivatizedInstance();
        newStarted += _this.tasksStarted.read();
        newFinished += _this.tasksFinished.read();
      }

      // Check if finished...
      if newStarted == newFinished && newStarted == started && newFinished == finished {
        // No change, termination of all tasks detected...
        return true;
      } else {
        // Not finished...
        return false;
      }
    }

    // Wait for the termination of all tasks. Minimum and maximum
    // backoff are in milliseconds
    proc awaitTermination(minBackoff = 0, maxBackoff = 1024, multBackoff = 2) {
      var state = 0;
      var started = 0;
      var finished = 0;
      var backoff = minBackoff;

      while true {
        select state {
          // Check if all counters add up to 0.
          when 0 {
            started = 0;
            finished = 0;
            for loc in Locales  do on loc {
              const _this = getPrivatizedInstance();
              started += _this.tasksStarted.read();
              finished += _this.tasksFinished.read();
            }

            // Check if all started tasks have finished
            if started == finished {
              state = 1;
              backoff = minBackoff;
              continue;
            }
          }
          // Check if all counters add up to what we had before...
          when 1 {
            var newStarted = 0;
            var newFinished = 0;
            for loc in Locales do on loc {
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
                continue;
              }
            } else {
              // Not finished...
              state = 0; 
            }
          }
        }

        if backoff == 0 then chpl_task_yield();
        else sleep(randInt(backoff), TimeUnits.milliseconds);
        backoff = min(backoff * multBackoff, maxBackoff);
      }
    }

    proc dsiPrivatize(pid) {
      return new unmanaged TerminationDetectorImpl(this, pid);
    }

    proc dsiGetPrivatizeData() {
      return pid;
    }

    inline proc getPrivatizedInstance() {
      return chpl_getPrivatizedCopy(this.type, pid);
    }
  }
}
