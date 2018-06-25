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
