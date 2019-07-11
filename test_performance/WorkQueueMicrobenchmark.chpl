use WorkQueue;
use Time;
use CyclicDist;

proc logN(val: integral, base: integral) return (log(val)/log(base)) : int;

record DuplicateRemover {
    proc this(A : [?D] int) {
        var set : domain(int);
        for a in A do set += a;
        // Bug for tuple size mismatch
        var ix = D.low;
        for s in set {
            A[ix] = s;
            ix += 1;
        }
        if ix < D.high then A[ix..] = -1; 
    }
}

var timer = new Timer();
config const N = 1024 * 1024;

timer.start();
var wqNoAgg = new WorkQueue(int, 0);
timer.stop();
writeln("Creation (No Aggregation): ", timer.elapsed());
timer.clear();

timer.start();
var wqLimitedAgg = new WorkQueue(int, 1024 * 1024);
timer.stop();
writeln("Creation (Limited Aggregation): ", timer.elapsed());
timer.clear();

timer.start();
var wqUnlimitedAgg = new WorkQueue(int, -1);
timer.stop();
writeln("Creation (Unlimited Aggregation): ", timer.elapsed());
timer.clear();

var cyclicDom = {1..N} dmapped Cyclic(startIdx=1);
timer.start();
forall idx in cyclicDom do wqNoAgg.addWork(idx);
timer.stop();
writeln("Insertion (local): ", timer.elapsed());
timer.clear();

timer.start();
forall idx in cyclicDom do wqNoAgg.getWork();
timer.stop();
writeln("Removal: ", timer.elapsed());
timer.clear();

/*timer.start();
forall idx in cyclicDom do wqNoAgg.addWork(idx, Locales[idx % numLocales]);
timer.stop();
writeln("Insertion (remote, no aggregation): ", timer.elapsed());
timer.clear();*/

timer.start();
forall idx in cyclicDom do wqLimitedAgg.addWork(idx, Locales[idx % numLocales]);
wqLimitedAgg.flush();
timer.stop();
writeln("Insertion (remote, limited aggregation): ", timer.elapsed());
timer.clear();

timer.start();
forall idx in cyclicDom do wqUnlimitedAgg.addWork(idx, Locales[idx % numLocales]);
wqUnlimitedAgg.flush();
timer.stop();
writeln("Insertion (remote, unlimited aggregation): ", timer.elapsed());
timer.clear();

timer.start();
var td = new TerminationDetector(cyclicDom.size);
forall work in doWorkLoop(wqUnlimitedAgg, td) {
    td.finished(1);
}
timer.stop();
writeln("doWorkLoop (no work): ", timer.elapsed());
timer.clear();

timer.start();
td.started(1);
wqUnlimitedAgg.addWork(0);
forall work in doWorkLoop(wqUnlimitedAgg, td) {
    if work < logN(N, numLocales) {
        td.started(numLocales);
        wqUnlimitedAgg.addWork(work + 1, Locales.id);
    }
    td.finished(1);
}
timer.stop();
writeln("doWorkLoop (work, no coalescing): ", timer.elapsed());
timer.clear();

timer.start();
wqNoAgg.destroy();
timer.stop();
writeln("Destruction: ", timer.elapsed());
timer.clear();

wqLimitedAgg.destroy();
wqUnlimitedAgg.destroy();


var wqCoalesced = new WorkQueue(int, -1, new DuplicateRemover());
timer.start();
td.started(1);
wqCoalesced.addWork(0);
forall work in doWorkLoop(wqCoalesced, td) {
    if work != -1 && work < logN(N, numLocales) {
        td.started(numLocales);
        wqCoalesced.addWork(work + 1, Locales.id);
    }
    td.finished(1);
}
timer.stop();
writeln("doWorkLoop (work, coalescing): ", timer.elapsed());
timer.clear();