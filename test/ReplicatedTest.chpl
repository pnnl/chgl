use CHGL;

var keepAlive = new Replicated(atomic bool);

// Writes are local
keepAlive.write(true);

// Reads are local
writeln(keepAlive);

// Global writes via promotion
keepAlive.broadcast.write(true);
coforall loc in Locales do on loc {
    // Gather
    writeln(keepAlive.broadcast);
}

begin {
    sleep(5, TimeUnits.seconds);
    keepAlive.broadcast.write(false);
}

coforall loc in Locales do on loc {
  while keepAlive.read() {
    chpl_task_yield();
  }
}

coforall loc in Locales do on loc {
    writeln(keepAlive.broadcast);
}

keepAlive.write(true);
keepAlive.onLocale(numLocales - 1).write(true);
coforall loc in Locales do on loc {
    writeln(keepAlive.broadcast);
}