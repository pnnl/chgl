use DestinationBuffers.chpl

record WorkQueue {
  var pid = -1;
  var instance;

  proc _value {
    if pid == -1 then halt("WorkQueue unitialized...");
    return chpl_getPrivatizedClass(instance.type, pid);
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
  var destBuffer : DestinationBuffer(workType);

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
      var (ptr, len) = destBuffer.aggregate(locid, work);
      if ptr != nil {
        // TODO: Profile if we need to fetch 'pid' in local variable
        // to avoid communications...
        on Locales[locid] {
          var arr : [1..len] workType;
          bulk_get(c_ptrTo(arr), 0, ptr, len);
          var _this = getPrivatizedInstance;
          
          // Append in bulk locally...
          var workHead : WorkQueueNode(workType);
          var workTail : workQueueNode(workType);
          for w in arr {
            var node = new WorkQueueNode(workType);
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
          workHead.prev = workTail;
          _this.tail = workTail;
          _this.release();
        }
      }
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

  proc getWork(work : workType) : (bool, workType) {
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
        delete tmp;
      }
    }
    release();'

    return (hasWork, work);
  }

  proc init(type workType) {
    this.workType = workType;
    this.complete();
    this.pid = _newPrivatizedClass(this);
  }
}
