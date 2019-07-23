use Time;
use CyclicDist;
use BlockDist;
use Random;
use CHGL;
use UnorderedAtomics;

/*
	Note: Always compile without bounds checking unless doing correctness testing!
	Bounds checking induces at least one GET per check for locales other than locale #0!
*/

config const doRemoteAtomics = true;
config const doNetworkAtomics = CHPL_NETWORK_ATOMICS != "none";
config const doUnorderedAtomics = CHPL_COMM == "ugni";
config const doAggregation = true;
config const printTiming = false;
config const N=10000000 * here.maxTaskPar; // number of updates
config const M=1000 * here.maxTaskPar * numLocales; // size of table

proc main() {
	// allocate main table and array of random ints
	const Mspace = {0..M-1};
	const D = Mspace dmapped Cyclic(startIdx=Mspace.low);
	var A: [D] atomic int; // RDMA Atomics
	var _A : [D] chpl__processorAtomicType(int); // Remote Execution

	const Nspace = {0..(N*numLocales - 1)};
	const D2 = Nspace dmapped Block(Nspace);
	var rindex: [D2] int;

	/* set up loop */
	fillRandom(rindex, 208); // the 208 is a seed
	forall r in rindex {
		r = mod(r, M);
	}

	var t: Timer;
	if doRemoteAtomics {
		t.start();
		/* main loop */
		forall r in rindex {
			_A[r].add(1); //atomic add
		}
		t.stop();
		if printTiming then writeln("Remote Atomics: ", t.elapsed());
		t.clear();
	}

	if doUnorderedAtomics {
		t.start();
		forall r in rindex {
			A[r].unorderedAdd(1);
		}
		t.stop();
		if printTiming then writeln("Unordered Atomics: ", t.elapsed());
		t.clear();
	}

	if doNetworkAtomics {
		t.start();
		forall r in rindex {
			A[r].add(1);
		}
		t.stop();
		if printTiming then writeln("Network Atomics: ", t.elapsed());
		t.clear();
	}

	beginProfile("AggregationBufferMicrobenchmark-Perf");
	if doAggregation {
		proc flushBuffer(buf, loc) {
			on loc {
				var arr = buf.getArray();
				buf.done();
				for idx in arr {
					local do _A[idx].add(1);
				} 
			}
		}
		// Test by powers of 2 from 2^10 to 2^20
		var bufSz = 1024;
		while bufSz <= 1024 * 1024 {
			var aggregator = new Aggregator(int, bufSz);
			t.start();
			sync forall r in rindex {
				const loc = getLocale(D, r);
				var buf = aggregator.aggregate(r, loc);
				if buf != nil {
					begin with (in buf, in loc) { 
						flushBuffer(buf, loc);
					}
				}
			}
			forall (buf,loc) in aggregator.flushGlobal() do flushBuffer(buf,loc);
			t.stop();
			aggregator.destroy();
			if printTiming then writeln("Aggregated Atomics (bufSz=", bufSz, "): ", t.elapsed());
			t.clear();
			bufSz *= 2;
		}
		
		var dynamicAggregator = new DynamicAggregator(int);
		t.start();
		forall r in rindex {
			const loc = getLocaleIdx(D, r);
			dynamicAggregator.aggregate(r, loc);
		}
		forall (buf, loc) in dynamicAggregator.flushGlobal() do flushBuffer(buf, loc);
		t.stop();
		if printTiming then writeln("Dynamic Aggregated: ", t.elapsed());
		t.clear();
		dynamicAggregator.destroy();
	}
	endProfile();
}
