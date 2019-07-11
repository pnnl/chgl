use CHGL;
use HashedDist;
use Time;
use CyclicDist;

config const N = 1024 * 1024;
var timer = new Timer();

timer.start();
var propertyMap = new PropertyMap(int);
timer.stop();
writeln("PropertyMap Creation: ", timer.elapsed());
timer.clear();

timer.start();
var dom : domain(int, parSafe=true) dmapped Hashed(idxType=int);
var arr : [dom] int;
timer.stop();
writeln("HashedDist Creation: ", timer.elapsed());
timer.clear();

timer.start();
var cyclicDom = {0..N} dmapped Cyclic(startIdx=0);
forall idx in cyclicDom do propertyMap.setProperty(idx, -1, aggregated=false);
timer.stop();
writeln("PropertyMap Insertion (no aggregation): ", timer.elapsed());
timer.clear();

timer.start();
forall idx in cyclicDom do propertyMap.setProperty(idx, -1, aggregated=true);
propertyMap.flushGlobal();
timer.stop();
writeln("PropertyMap Insertion (aggregation): ", timer.elapsed());
timer.clear();

timer.start();
forall idx in cyclicDom with (ref dom, ref arr) {
    dom += idx;
}
timer.stop();
writeln("HashedDist Insertion: ", timer.elapsed());
timer.clear();

timer.start();
forall idx in cyclicDom do propertyMap.getProperty(idx);
timer.stop();
writeln("PropertyMap Retrieval: ", timer.elapsed());
timer.clear();

timer.start();
forall idx in cyclicDom do arr[idx];
timer.stop();
writeln("HashedDist Retrieval: ", timer.elapsed());
timer.clear();