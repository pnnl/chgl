use Benchmark;
use AdjListHyperGraph;
use Generation;
use BinReader;

// TODO: Need to make userData generic in Benchmark
var dummyGraph = new AdjListHyperGraph(10,15);
type graphType = dummyGraph.type;
delete dummyGraph;

var plotter : Plotter(int, real);
runBenchmarkMultiplePlotted(
    initFn = lambda(bmd : BenchmarkMetaData) : object {
      return new AdjListHyperGraph(10, 15);
    },
    benchFn = lambda(bd : BenchmarkData) {
      var graph = bd.userData : graphType;
      for i in 1 .. bd.iterations {
        fast_adjusted_erdos_renyi_hypergraph(graph, graph.vertices_dom, graph.edges_dom, 0.6);
      }
    },
    deinitFn = lambda(obj : object) {
      delete obj;
    },
    targetLocales=(1,2,4,8,16,32),
    benchName = "Adjacency List",
    plotter = plotter
);

plotter.plot("ChungLuPerf");
