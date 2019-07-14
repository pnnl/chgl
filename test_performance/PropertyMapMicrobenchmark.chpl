use CHGL;
use HashedDist;
use Time;
use CyclicDist;

config const N = 1024 * 1024;
config const printTiming = false;
var timer = new Timer();

timer.start();
var propertyMap = new PropertyMap(int);
timer.stop();
if printTiming then writeln("PropertyMap Creation: ", timer.elapsed());
timer.clear();

timer.start();
var dom : domain(int, parSafe=true) dmapped Hashed(idxType=int);
var arr : [dom] int;
timer.stop();
if printTiming then writeln("HashedDist Creation: ", timer.elapsed());
timer.clear();

timer.start();
var cyclicDom = {0..N} dmapped Cyclic(startIdx=0);
forall idx in cyclicDom do propertyMap.setProperty(idx, -1, aggregated=false);
timer.stop();
if printTiming then writeln("PropertyMap Insertion (no aggregation): ", timer.elapsed());
timer.clear();

timer.start();
forall idx in cyclicDom do propertyMap.setProperty(idx, -1, aggregated=true);
propertyMap.flushGlobal();
timer.stop();
if printTiming then writeln("PropertyMap Insertion (aggregation): ", timer.elapsed());
timer.clear();

timer.start();
forall idx in cyclicDom with (ref dom, ref arr) {
    dom += idx;
}
timer.stop();
if printTiming then writeln("HashedDist Insertion: ", timer.elapsed());
timer.clear();

timer.start();
forall idx in cyclicDom do propertyMap.getProperty(idx);
timer.stop();
if printTiming then writeln("PropertyMap Retrieval: ", timer.elapsed());
timer.clear();

timer.start();
{
    var propertyHandles : [cyclicDom] shared PropertyHandle;
    forall idx in cyclicDom do propertyHandles[idx] = propertyMap.getPropertyAsync(idx);
    propertyMap.flushGlobal();
}
timer.stop();
if printTiming then writeln("PropertyMap Retrieval (aggregated): ", timer.elapsed());
timer.clear();

timer.start();
forall idx in cyclicDom do arr[idx];
timer.stop();
if printTiming then writeln("HashedDist Retrieval: ", timer.elapsed());
timer.clear();