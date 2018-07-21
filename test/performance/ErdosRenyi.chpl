use AdjListHyperGraph;
use Memory;
use CommDiagnostics;
use Generation;
use Time;
use Random;

/* Performance Test for ChungLu algorithm */
config const isPrivatized = true;
config const numVertices = 1024 * 1024;
config const isNaive = false;
config const isBuffered = true;
config const numEdges = numVertices * 2;
config const profileCommunications = false;
config const probability = .01;
var edgeProbability = probability;
config const profileVerboseCommunications = false;

if profileCommunications then startCommDiagnostics();
if profileVerboseCommunications then startVerboseComm();

var graph = new AdjListHyperGraph(numVertices, numEdges, new Cyclic(startIdx=0, targetLocales=Locales));
var timer = new Timer();
timer.start();
if isNaive then generateErdosRenyiNaive(graph, graph.verticesDomain, graph.edgesDomain, edgeProbability);
else if numLocales == 1 then generateErdosRenyiSMP(graph, edgeProbability);
else if !isPrivatized {
  var _graph = graph._value;
  var inclusionsToAdd = round(graph.numVertices * graph.numEdges * edgeProbability) : int;
  // Perform work evenly across all locales
  coforall loc in Locales do on loc {
    var perLocaleInclusions = inclusionsToAdd / numLocales + (if here.id == 0 then inclusionsToAdd % numLocales else 0);
    coforall tid in 0..#here.maxTaskPar {
      // Perform work evenly across all tasks
      var perTaskInclusions = perLocaleInclusions / here.maxTaskPar + (if tid == 0 then perLocaleInclusions % here.maxTaskPar else 0);
      // Each thread gets its own random stream to avoid acquiring sync var
      var _randStream = new RandomStream(int, here.id * here.maxTaskPar + tid);
      var randStream = new RandomStream(int, _randStream.getNext());
      for 1..perTaskInclusions {
        var vertex = randStream.getNext(0, graph.numVertices - 1);
        var edge = randStream.getNext(0, graph.numEdges - 1);
        
        var vLoc = _graph._vertices.domain.dist.idxToLocale(vertex);
        var eLoc = _graph._edges.domain.dist.idxToLocale(edge);

        // Both not on same node? Ensure that both remote operations are handled remotely
        serial vLoc != here && eLoc != here do
          cobegin {
            _graph._vertices[vertex].addNodes(edge : _graph.eDescType);
            _graph._edges[edge].addNodes(vertex : _graph.vDescType);
          }

      }
    }
  }
} else if isBuffered then generateErdosRenyi(graph, edgeProbability);
else generateErdosRenyiUnbuffered(graph, edgeProbability);
timer.stop();


writeln("Time:", timer.elapsed());
writeln("Probability:", edgeProbability);
writeln("Nodes:", numLocales);
writeln("NumVertices:", numVertices);
writeln("NumEdges:", numEdges);
writeln("Memory Used: ", memoryUsed());
writeln("ProbabilityMultiple:", probability);
writeln("Naive:", isNaive);
writeln("Contention:", Debug.contentionCnt);
writeln("maxTaskPar:", here.maxTaskPar);

if profileCommunications then writeln(getCommDiagnostics());
