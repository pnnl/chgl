use Time;
use Plot;

record BenchmarkMetaData {
  // Total numberof iterations to be run across all nodes...
  var totalOps : int;
  // Locales that will be used in this benchmark...
  var targetLocDom : domain(1);
  var targetLocales : [targetLocDom] locale;
}

record BenchmarkResult {
  // Time in seconds requested units...
  var time : real;
  // The requested units... needed for calculating 'opsPerSec'
  var unit : TimeUnits;
  // Number of operations performed...
  var operations : int;
  // Number of locales used for this benchmark...
  var nLocales : int;

  inline proc timeInSeconds {
      select unit {
        when TimeUnits.microseconds do return time *    1.0e-6;
        when TimeUnits.milliseconds do return time *    1.0e-3;
        when TimeUnits.seconds      do return time;
        when TimeUnits.minutes      do return time *   60.0;
        when TimeUnits.hours        do return time * 3600.0;
    }

    halt("TimeUnit ", unit, " is not supported...");
  }

  inline proc opsPerSec {
    return operations / timeInSeconds;
  }
}

record BenchmarkData {
  // User created data from 'initFn' which also gets cleaned up in 'deinitFn'.
  var userData : object;
  // Number of iterations to run for this task...
  var iterations : int;
}

config param benchmarkLogN = false;

// Runs a benchmark and returns the result for the target number of locales.
proc runBenchmark(
  benchFn : func(BenchmarkData, void),
  benchTime : real = 1,
  unit: TimeUnits = TimeUnits.seconds,
  initFn : func(BenchmarkMetaData, object) = nil,
  deinitFn : func(object, void) = nil,
  targetLocales : [?targetLocDom] = Locales,
  isWeakScaling : bool = false,
  serialWork : bool = false
) : BenchmarkResult {
  // Assertion
  if benchFn == nil {
    halt("'benchFn' must be non-nil!");
  }

  // Find the 'sweet-spot' for this benchmark that runs for specified amount of time.
  var n = 1;
  var timer = new Timer();
  while n < 1e12 {
    if benchmarkLogN then writeln("N=", n);
    var benchData : BenchmarkData;
    var nLocales = targetLocales.size;
    var totalOps = if isWeakScaling && serialWork then n * nLocales else n;
    benchData.iterations = (totalOps / nLocales) / here.maxTaskPar;

    // Don't distribute work individually?
    if !serialWork then benchData.iterations = n;

    if initFn != nil {
      var meta = new BenchmarkMetaData(targetLocales=targetLocales, targetLocDom=targetLocDom, totalOps=totalOps);
      benchData.userData = initFn(meta);
    }

    timer.clear();
    timer.start();

    if serialWork {
      coforall loc in targetLocales do on loc {
        coforall tid in 0..#here.maxTaskPar {
          benchFn(benchData);
        }
      }
    } else {
      benchFn(benchData);
    }

    timer.stop();
    if deinitFn {
      deinitFn(benchData.userData);
    }

    if timer.elapsed(unit) >= benchTime {
      return new BenchmarkResult(time=timer.elapsed(unit), unit=unit, operations=totalOps, nLocales=targetLocales.size);
    }

    n *= 2;
  }

  halt("Exceeded 'n' of 1e12...");
}

// Runs multiple benchmarks for the specified tuple of targetLocales and and returns an array of results.
proc runBenchmarkMultiple(
  benchFn : func(BenchmarkData, void),
  benchTime : real = 1,
  unit: TimeUnits = TimeUnits.seconds,
  initFn : func(BenchmarkMetaData, object) = nil,
  deinitFn : func(object, void) = nil,
  isWeakScaling : bool = false,
  serialWork : bool = false,
  targetLocales
) {
  var results : targetLocales.size * BenchmarkResult;
  var idx = 1;
  for targetLoc in targetLocales {
    if targetLoc > numLocales then continue;
    var subLocales : [{0..#targetLoc}] locale;
    for i in 0 .. #targetLoc do subLocales[i] = Locales[i];

    results[idx] = runBenchmark(benchFn, benchTime, unit, initFn, deinitFn, subLocales, isWeakScaling, serialWork);
    idx = idx + 1;
  }
  return results;
}

proc runBenchmarkMultiplePlotted(
  benchFn : func(BenchmarkData, void),
  benchTime : real = 1,
  unit: TimeUnits = TimeUnits.seconds,
  initFn : func(BenchmarkMetaData, object) = nil,
  deinitFn : func(object, void) = nil,
  isWeakScaling : bool = false,
  serialWork : bool = false,
  targetLocales,
  benchName : string,
  ref plotter : Plotter(int, real)
) {
  var results = runBenchmarkMultiple(benchFn, benchTime, unit, initFn, deinitFn, isWeakScaling, serialWork, targetLocales);
  for result in results {
    if result.operations == 0 || result.time == 0 then continue;
    writeln("[", benchName, "]: nLocales=", result.nLocales, ", N=", result.operations, ", Op/Sec=", result.opsPerSec);
    plotter.add(benchName, result.nLocales, result.opsPerSec);
  }
}


proc benchmarkAtomics() {
  class atomicCounter { var c : atomic uint; }
  var plotter : Plotter(int, real);
  runBenchmarkMultiplePlotted(
      benchFn = lambda(bd : BenchmarkData) {
        var counter = bd.userData : atomicCounter;
        for i in 1 .. bd.iterations {
            counter.c.fetchAdd(1);
        }
      },
      initFn = lambda(bmd : BenchmarkMetaData) : object {
        return new atomicCounter();
      },
      deinitFn = lambda(obj : object) {
        delete obj;
      },
      targetLocales=(1,2,4,8,16,32),
      benchName = "AtomicFetchAdd",
      plotter = plotter
  );

  plotter.plot("AtomicFetchAdd");
}

proc main() {
  benchmarkAtomics();
}
