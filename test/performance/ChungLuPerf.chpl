use Benchmark;
use AdjListHyperGraph;
use Generation;
use BinReader;

// TODO: Need to make userData generic in Benchmark
const vertex_domain = {1..1} dmapped Cyclic(startIdx=0);
const edge_domain = {1..1} dmapped Cyclic(startIdx=0);
var dummyGraph = new AdjListHyperGraph(vertex_domain, edge_domain);
type graphType = dummyGraph.type;
delete dummyGraph;

var plotter : Plotter(int, real);
runBenchmarkMultiplePlotted(
    initFn = lambda(bmd : BenchmarkMetaData) : object {
      const vertex_domain = {0..#bmd.totalOps} dmapped Cyclic(startIdx=0);
      const edge_domain = {0..#(bmd.totalOps * 2)} dmapped Cyclic(startIdx=0);
      return new AdjListHyperGraph(vertex_domain, edge_domain);
    },
    benchFn = lambda(bd : BenchmarkData) {
      var graph = bd.userData : graphType;
      writeln("|V| = ", graph.vertices_dom, ", |E| = ", graph.edges_dom);
      fast_adjusted_erdos_renyi_hypergraph(graph, graph.vertices_dom, graph.edges_dom, 0.6);
    },
    deinitFn = lambda(obj : object) {
      delete obj;
    },
    targetLocales=(1,2,4,8,16,32),
    benchName = "Adjacency List",
    plotter = plotter
);

plotter.plot("ChungLuPerf");
