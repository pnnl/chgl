use CHGL;
use Time;
use CyclicDist;

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

timer.start();
forall idx in cyclicDom do wqNoAgg.addWork(idx, Locales[idx % numLocales]);
timer.stop();
writeln("Insertion (remote, no aggregation): ", timer.elapsed());
timer.clear();

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
wqUnlimitedAgg.addWork(1);
forall work in doWorkLoop(wqUnlimitedAgg, td) {
    if work < 10 {
        td.started(numLocales);
        wqUnlimitedAgg.addWork(work + 1, Locales.id);
    }
    td.finished(1);
}