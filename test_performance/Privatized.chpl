use CHGL;
use ReplicatedDist;
use ReplicatedVar;
use Time;

config const N = 1024 * 1024;
var timer = new Timer();
var privatizedAtomic = new Privatized(atomic int);
var replicatedAtomic : [rcDomain] atomic int;
var privatizedInteger = new Privatized(int);
var replicatedInteger : [rcDomain] int;

timer.start();
coforall loc in Locales do on loc {
    coforall tid in 1..here.maxTaskPar {
        for i in 1..N {
            privatizedAtomic.add(1);
        }
    }
}
timer.stop();
writeln("Privatized Local Atomic: ", timer.elapsed());
timer.clear();

timer.start();
coforall loc in Locales do on loc {
    coforall tid in 1..here.maxTaskPar {
        for i in 1..N {
            privatizedInteger = 1;
        }
    }
}
timer.stop();
writeln("Privatized Local Integer: ", timer.elapsed());
timer.clear();

timer.start();
coforall loc in Locales do on loc {
    coforall tid in 1..here.maxTaskPar {
        for i in 1..N {
            rcLocal(replicatedAtomic).add(1);
        }
    }
}
timer.stop();
writeln("ReplicatedVar Local Atomic: ", timer.elapsed());
timer.clear();

timer.start();
coforall loc in Locales do on loc {
    coforall tid in 1..here.maxTaskPar {
        for i in 1..N {
            rcLocal(replicatedInteger) = 1;
        }
    }
}
timer.stop();
writeln("ReplicatedVar Local Integer: ", timer.elapsed());
timer.clear();

timer.start();
coforall loc in Locales do on loc {
    coforall tid in 1..here.maxTaskPar {
        for i in 1..N {
            privatizedAtomic.get(i % numLocales).add(1);
        }
    }
}
timer.stop();
writeln("Privatized Remote Atomic: ", timer.elapsed());
timer.clear();

timer.start();
coforall loc in Locales do on loc {
    coforall tid in 1..here.maxTaskPar {
        for i in 1..N {
            privatizedInteger.get(i % numLocales) = 1;
        }
    }
}
timer.stop();
writeln("Privatized Remote Integer: ", timer.elapsed());
timer.clear();

timer.start();
coforall loc in Locales do on loc {
    coforall tid in 1..here.maxTaskPar {
        for i in 1..N {
            on Locales[i % numLocales] do rcLocal(replicatedAtomic).add(1);
        }
    }
}
timer.stop();
writeln("ReplicatedVar Remote Atomic: ", timer.elapsed());
timer.clear();

timer.start();
coforall loc in Locales do on loc {
    coforall tid in 1..here.maxTaskPar {
        for i in 1..N {
            on Locales[i % numLocales] do rcLocal(replicatedInteger) = 1;
        }
    }
}
timer.stop();
writeln("ReplicatedVar Remote Integer: ", timer.elapsed());
timer.clear();

timer.start();
coforall loc in Locales do on loc {
    coforall tid in 1..here.maxTaskPar {
        for i in 1..N {
            privatizedAtomic.broadcast.add(1);
        }
    }
}
timer.stop();
writeln("Privatized Broadcast Atomic: ", timer.elapsed());
timer.clear();

timer.start();
coforall loc in Locales do on loc {
    coforall tid in 1..here.maxTaskPar {
        for i in 1..N {
            privatizedInteger.broadcast = 1;
        }
    }
}
timer.stop();
writeln("Privatized Broadcast Integer: ", timer.elapsed());
timer.clear();

timer.start();
coforall loc in Locales do on loc {
    coforall tid in 1..here.maxTaskPar {
        for i in 1..N {
            coforall _loc in Locales do on _loc do rcLocal(replicatedAtomic).add(1);
        }
    }
}
timer.stop();
writeln("ReplicatedVar Broadcast Atomic: ", timer.elapsed());
timer.clear();

timer.start();
coforall loc in Locales do on loc {
    coforall tid in 1..here.maxTaskPar {
        for i in 1..N {
            coforall _loc in Locales do on _loc do rcLocal(replicatedInteger) = 1;
        }
    }
}
timer.stop();
writeln("ReplicatedVar Broadcast Integer: ", timer.elapsed());
timer.clear();