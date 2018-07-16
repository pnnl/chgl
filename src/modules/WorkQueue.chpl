use DestinationBuffers;

record WorkQueue {
  var instance;
  var pid = -1;
  
  proc init(type workType) {
    this.instance = new WorkQueueImpl(workType);
    this.pid = this.instance.pid;
  }

  proc _value {
    if pid == -1 then halt("WorkQueue unitialized...");
    return chpl_getPrivatizedCopy(instance.type, pid);
  }

  forwarding _value;
}

class WorkQueueNode {
  type workType;
  var work : workType;
  var next : WorkQueueNode(workType);
  var prev : WorkQueueNode(workType);

  proc init(work : ?workType) {
    this.workType = workType;
    this.work = work;
  }
}

// TODO: Use CC-Synch algorithm for scalability...
class WorkQueueImpl {
  type workType;
  var pid = -1;
  var lock$ : atomic bool;
  var head : WorkQueueNode(workType);
  var tail : WorkQueueNode(workType);
  var destBuffer = new AggregationBuffer(workType);
  
  proc init(type workType) {
    this.workType = workType;
    this.complete();
    this.pid = _newPrivatizedClass(this);
  }

  proc init(other, pid) {
    this.workType = other.workType;
    this.pid = pid;
  }

  proc dsiPrivatize(pid) {
    return new WorkQueueImpl(this, pid);
  }

  proc dsiGetPrivatizeData() {
    return pid;
  }

  inline proc getPrivatizedInstance() {
    return chpl_getPrivatizedCopy(this.type, pid);
  }

  inline proc acquire() {
    // Fast path
    var ret = lock$.testAndSet();
    if ret == false then return;
    
    // Slow path (Test and Test and Set)
    while true {
      ret = lock$.peek();
      if ret == true {
        chpl_task_yield();
        continue;
      }

      ret = lock$.testAndSet();
      if ret == false then break;
    }
  }

  inline proc release() {
    lock$.clear();
  }

  proc addWork(work : workType, locid = here.id) {
    if locid != here.id {
      var buffer = destBuffer.aggregate(locid, work);
      if buffer != nil {
        // TODO: Profile if we need to fetch 'pid' in local variable
        // to avoid communications...
        begin on Locales[locid] {
          var arr = buffer.getArray();
          var _this = getPrivatizedInstance();
          
          // Append in bulk locally...
          var workHead : WorkQueueNode(workType);
          var workTail : WorkQueueNode(workType);
          for w in arr {
            var node = new WorkQueueNode(w);
            if workHead == nil {
              workHead = node;
              workTail = workHead;
            } else {
              workTail.next = node;
              node.prev = workTail;
              workTail = node;
            }
          }
          on this do destBuffer.processed(buffer);
          _this.acquire();
          _this.tail.next = workHead;
          workHead.prev = _this.tail;
          _this.tail = workTail;
          _this.release();
        }
      }
      return;
    }

    // Handle local adding work
    acquire();
    
    var node = new WorkQueueNode(work);
    if head == nil {
      head = node;
      tail = head;
    } else {
      tail.next = node;
      node.prev = tail;
      tail = node;
    }

    release();
  }

  proc getWork() : (bool, workType) {
    var (hasWork, work) : (bool, workType);
    
    acquire();
    if head != nil {
      assert(tail != nil);
      hasWork = true;
      work = head.work;
      
      // Cleanup list
      if head == tail {
        delete head;
        head = nil;
        tail = nil;
      } else {
        var tmp = head;
        head = head.next;
        head.prev = nil;
        delete tmp;
      }
    }
    release();

    return (hasWork, work);
  }

  proc flush() {
    forall arr in destBuffer.flushLocal() {
      var _this = getPrivatizedInstance();

      // Append in bulk locally...
      var workHead : WorkQueueNode(workType);
      var workTail : WorkQueueNode(workType);
      for w in arr {
        var node = new WorkQueueNode(w);
        if workHead == nil {
          workHead = node;
          workTail = workHead;
        } else {
          workTail.next = node;
          node.prev = workTail;
          workTail = node;
        }
      }
      _this.acquire();
      _this.tail.next = workHead;
      workHead.prev = _this.tail;
      _this.tail = workTail;
      _this.release();
    }
  }
}

proc main() {
  var wq = new WorkQueue(int);
  coforall loc in Locales with (in wq) do on loc {
    forall i in 1..10 {
      wq.addWork(locid = i % numLocales, work = i+1);
    }
    wq.flush();
  }


  coforall loc in Locales with (in wq) do on loc {
    var (hasWork, work) = wq.getWork();
    while hasWork {
      writeln(here, ": Received ", work);
      (hasWork, work) = wq.getWork();
    }
  }
}
