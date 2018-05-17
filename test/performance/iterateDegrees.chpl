use Benchmark;
use AdjListHyperGraph;
use BinReader;

var graph = readFile("../../baylor-nodupes.bin");
var plotter : Plotter(int, real);
runBenchmarkMultiplePlotted(
    benchFn = lambda(bd : BenchmarkData) {
      for i in 1 .. bd.iterations {
        forall (v, vdeg) in graph.forEachVertexDegree() {
          if vdeg < 0 then halt(vdeg);
        }
      }
    },
    targetLocales=(1,2,4,8,16,32),
    benchName = "Adjacency List",
    plotter = plotter
);

plotter.plot("IterateDegrees");
