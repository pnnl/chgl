use AggregationBuffer;
use LocalAtomicObject;
use VisualDebug;

pragma "always RVF"
record WorkQueue {
  var instance;
  var pid = -1;
  
  proc init(type workType) {
    this.instance = new unmanaged WorkQueueImpl(workType);
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
  var next : unmanaged WorkQueueNode(workType);
  var prev : unmanaged WorkQueueNode(workType);

  proc init(work : ?workType) {
    this.workType = workType;
    this.work = work;
  }
}

class WorkQueueImpl {
  type workType;
  var pid = -1;
  var queue = new unmanaged CCQueue(workType); 
  var destBuffer = new Aggregator(workType);
  
  proc init(type workType) {
    this.workType = workType;
    this.complete();
    this.pid = _newPrivatizedClass(_to_unmanaged(this));
  }

  proc init(other, pid) {
    this.workType = other.workType;
    this.pid = pid;
  }

  proc dsiPrivatize(pid) {
    return new unmanaged WorkQueueImpl(this, pid);
  }

  proc dsiGetPrivatizeData() {
    return pid;
  }

  inline proc getPrivatizedInstance() {
    return chpl_getPrivatizedCopy(this.type, pid);
  }
  proc addWork(work : workType, loc : locale) {
    addWork(work, loc.id);
  }

  proc addWork(work : workType, locid = here.id) {
    if locid != here.id {
      var buffer = destBuffer.aggregate(work, locid);
      if buffer != nil {
        // TODO: Profile if we need to fetch 'pid' in local variable
        // to avoid communications...
        begin on Locales[locid] {
          var arr = buffer.getArray();
          var _this = getPrivatizedInstance();
          buffer.done();
          queue.bulkEnqueue(arr);
        }
      }
      return;
    }

    queue.enqueue(work);
  }

  proc getWork() : (bool, workType) {
    return queue.dequeue();
  }

  proc flush() {
    forall (buf, loc) in destBuffer.flushGlobal() do on loc {
      var _this = getPrivatizedInstance();
      var arr = buf.getArray();
      buf.done();
      _this.queue.bulkEnqueue(arr);
    }
  }

  proc deinit() {
    delete queue;
  }
}

class CCSynchEnqueueNode {
  type eltType;

  // Head and Tail to enqueue
  var head : unmanaged QueueNode(eltType);
  var tail : unmanaged QueueNode(eltType);

  // If wait is false, we spin
  // If wait is true, but completed is false, we are the new combiner thread
  // If wait is true and completed is true, we are done and can exit
  var wait : atomic bool;
  var completed : bool;

  // Next in the waitlist
  var next : unmanaged CCSynchEnqueueNode(eltType);

  proc init(type eltType, head : unmanaged QueueNode(eltType) = nil, tail : unmanaged QueueNode(eltType) = nil) {
    this.eltType = eltType;
    this.head = head;
    this.tail = tail;
  }
}

class CCSynchDequeueNode {
  type eltType;

  // Used for return value if dequeue, or element to be added if enqueue
  var ret : eltType;
  var found : bool;

  // If wait is false, we spin
  // If wait is true, but completed is false, we are the new combiner thread
  // If wait is true and completed is true, we are done and can exit
  var wait : atomic bool;
  var completed : bool;

  // Next in the waitlist
  var next : unmanaged CCSynchDequeueNode(eltType);

  proc init(type eltType) {
    this.eltType = eltType;
  }
}

// Maybe an unrolled linked list?
class QueueNode {
  type eltType;
  var elt : eltType;
  var next : unmanaged QueueNode(eltType);

  proc init(type eltType) {
    this.eltType = eltType;
  }

  proc init(elt : ?eltType) {
    this.eltType = eltType;
    this.elt = elt;
  }
}

class CCQueue {
  type eltType;
  var maxRequests = 1024;

  var head : unmanaged QueueNode(eltType);
  var dequeueWaitList : LocalAtomicObject(unmanaged CCSynchDequeueNode(eltType));
  var tail : unmanaged QueueNode(eltType);
  var enqueueWaitList : LocalAtomicObject(unmanaged CCSynchEnqueueNode(eltType));

  proc init(type eltType) {
    this.eltType = eltType;

    // Create a dummy node...
    var n = new unmanaged QueueNode(eltType);
    head = n;
    tail = n;

    this.complete();

    // Construct CCSynch wait list...
    dequeueWaitList.write(new unmanaged CCSynchDequeueNode(eltType));
    enqueueWaitList.write(new unmanaged CCSynchEnqueueNode(eltType));
  }

  proc bulkEnqueue(arr : [?dom] eltType) {
    on this {
      // Append in bulk locally...
      var workHead : unmanaged QueueNode(eltType);
      var workTail : unmanaged QueueNode(eltType);
      for w in arr {
        var node = new unmanaged QueueNode(w);
        if workHead == nil {
          workHead = node;
          workTail = workHead;
        } else {
          workTail.next = node;
          workTail = node;
        }
      }

      doEnqueue(workHead, workTail);
    }
  }

  proc enqueue(elt : eltType) {
    on this do doEnqueue(new unmanaged QueueNode(elt));
  }

  proc doEnqueue(head : unmanaged QueueNode(eltType), tail = head) {
    var counter = 0;
    var nextNode = new unmanaged CCSynchEnqueueNode(eltType, head, tail);
    nextNode.wait.write(true);
    nextNode.completed = false;

    // Register our dummy node so that the next task can add theirs safely,
    // then fill out the node we assigned to use
    var currNode = enqueueWaitList.exchange(nextNode);
    currNode.head = head;
    currNode.tail = tail;
    currNode.next = nextNode;

    // Spin until we are finished...
    currNode.wait.waitFor(false);

    // If our operation is marked complete, we may safely reclaim it, as it is no
    // longer being touched by the combiner thread
    if currNode.completed {
      delete currNode;
      return;
    }

    // If we are not marked as complete, we *are* the combiner thread
    var tmpNode = currNode;
    var tmpNodeNext : unmanaged CCSynchEnqueueNode(eltType);

    while (tmpNode.next != nil && counter < maxRequests) {
      counter = counter + 1;
      // Note: Ensures that we do not touch the current node after it is freed
      // by the owning thread...
      tmpNodeNext = tmpNode.next;

      // Process...
      this.tail.next = tmpNode.head; 
      this.tail = tmpNode.tail;

      // We are done with this one... Note that this uses an acquire barrier so
      // that the owning task sees it as completed before wait is no longer true.
      tmpNode.completed = true;
      tmpNode.wait.write(false);

      tmpNode = tmpNodeNext;
    }

    // At this point, it means one thing: Either we are on the dummy node, on which
    // case nothing happens, or we exceeded the number of requests we can do at once,
    // meaning we wake up the next thread as the combiner.
    tmpNode.wait.write(false);
    delete currNode;
  }

  proc dequeue () : (bool, eltType) {
    var retval : (bool, eltType);
    on this do retval = doDequeue();
    return retval;
  }

  proc doDequeue () : (bool, eltType) {
    var counter = 0;
    var nextNode = new unmanaged CCSynchDequeueNode(eltType);
    nextNode.wait.write(true);
    nextNode.completed = false;

    // Register our dummy node so that the next task can add theirs safely,
    // then fill out the node we assigned to use
    var currNode = dequeueWaitList.exchange(nextNode);
    currNode.next = nextNode;

    // Spin until we are finished...
    currNode.wait.waitFor(false);

    // If our operation is marked complete, we may safely reclaim it, as it is no
    // longer being touched by the combiner thread
    if currNode.completed {
      var (present, elt) = (currNode.found, currNode.ret);
      delete currNode;
      return (present, elt);
    }

    // If we are not marked as complete, we *are* the combiner thread
    var tmpNode = currNode;
    var tmpNodeNext : unmanaged CCSynchDequeueNode(eltType);

    while (tmpNode.next != nil && counter < maxRequests) {
      counter = counter + 1;
      // Note: Ensures that we do not touch the current node after it is freed
      // by the owning thread...
      tmpNodeNext = tmpNode.next;

      // Process...
      var node = this.head;
      var newHead = this.head.next;

      // Has some item
      if newHead != nil {
        // Grab and clean up
        tmpNode.ret = newHead.elt;
        tmpNode.found = true;
        head = newHead;
        delete node;
      }

      // We are done with this one... Note that this uses an acquire barrier so
      // that the owning task sees it as completed before wait is no longer true.
      tmpNode.completed = true;
      tmpNode.wait.write(false);

      tmpNode = tmpNodeNext;
    }

    // At this point, it means one thing: Either we are on the dummy node, on which
    // case nothing happens, or we exceeded the number of requests we can do at once,
    // meaning we wake up the next thread as the combiner.
    tmpNode.wait.write(false);
    var (present, elt) = (currNode.found, currNode.ret);
    delete currNode;
    return (present, elt);
  }

  proc deinit() {
    delete head;
  }
}

proc main() {
  startVdebug("WorkQueueVisual");
  var wq = new WorkQueue(int);
  coforall loc in Locales with (in wq) do on loc {
    forall i in 1..1024 * 1024 {
      wq.addWork(locid = i % numLocales, work = i);
    }
    wq.flush();
  }

  tagVdebug("Add");

  var total : int;
  coforall loc in Locales with (in wq, + reduce total) do on loc {
    coforall tid in 1..here.maxTaskPar with (+ reduce total) {
      var (hasWork, work) = wq.getWork();
      while hasWork {
        total += work; 
        (hasWork, work) = wq.getWork();
      }
    }
  }
  tagVdebug("Sum");
  assert(total == (+ reduce (1..1024 * 1024)) * numLocales, "Expected: ", (+ reduce (1..1024 * 1024)) * numLocales, ", received: ", total);
  stopVdebug();
}
