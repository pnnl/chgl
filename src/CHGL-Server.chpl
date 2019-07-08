use AdjListHyperGraph;
use Graph;
use BinReader;
use Butterfly;
use Metrics;
use Generation;
use TerminationDetection;
use Traversal;
use Utilities;
use Visualize;
use WorkQueue;
use AggregationBuffer;
use DynamicAggregationBuffer;

config const ServerPort = 5555;
param SYN = 0x0;
param ACK = 0x1;
param CREATE_GRAPH = 0x2;
param ADD_INCLUSION = 0x3;
param GET_SIZE = 0x4;

// Runs as a server-client program
proc main() {
  use ZMQ;  
  // create and connect ZMQ socket
  var shutdownServer = false;
  var context: ZMQ.Context;
  var socket = context.socket(ZMQ.REP);
  socket.bind("tcp://*:%t".format(ServerPort));
  writeln("server listening on %s:%t".format(get_hostname(), ServerPort)); try! stdout.flush();

  // Currently we only have one graph, the AdjListHyperGraph, and only one instance of it...
  var graph = new AdjListHyperGraph(1,1);
  while !shutdownServer {
    var reqMsg = socket.recv(string);
    var fields = reqMsg.split(":");
    var msgType = fields[1];
    select msgType:int {
      when SYN {
        writeln("[SYN] Received.");
        socket.send(ACK);
      }
      when GET_SIZE {
        writeln("[GET_SIZE] Received.");
        socket.send(graph.getInclusions());
      }
      when CREATE_GRAPH {
        var (numVertices, numEdges) = (fields[2]:int, fields[3]:int);
        writeln("[CREATE_GRAPH] Received request for graph with ", numVertices, " vertices and ", numEdges, " edges.");
        socket.send(ACK);
        graph = new AdjListHyperGraph(numVertices, numEdges);
      }
      when ADD_INCLUSION {
        writeln("[ADD_INCLUSION] Received request for ", fields.size - 1, " inclusions.");
        socket.send(ACK);
        forall inclusion in fields[2..] do if !inclusion.isEmpty() {
          try {
            var subfields = inclusion.split(",").strip();
            graph.addInclusion(subfields[1][2..]:int, subfields[2][..subfields[2].size - 1]:int);
          } catch e : Error {
            writeln("Bad string: ", inclusion, ", error: ", e);
          }
        }
      }
      otherwise {
        writeln("Received bad command: '", reqMsg, "', Sending 'ACK'.");
        socket.send(ACK);
      }
    }
  }
}

proc get_hostname(): string {
  /* The right way to do this is by reading the hostname from stdout, but that 
     causes a segfault in a multilocale setting. So we have to use a temp file, 
     but we can't use opentmp, because we need the name and the .path attribute 
     is not the true name. */
  use Spawn;
  use IO;
  use FileSystem;
  const tmpfile = '/tmp/CHGL.hostname';
  if exists(tmpfile) {
    remove(tmpfile);
  }
  var cmd = "hostname > \"%s\"".format(tmpfile);
  var sub = spawnshell(cmd);
  sub.wait();
  var hostname: string;
  var f = open(tmpfile, iomode.r);
  var r = f.reader();
  r.readstring(hostname);
  r.close();
  f.close();
  remove(tmpfile);
  return hostname.strip();
}
