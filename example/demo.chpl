use CHGL; // Includes all core and utility components of CHGL
use Time; // For Timer

/*
    Part 1: Global-View Distributed Data Structures
*/
// Question: How do we create a toy hypergraph?
// Answer: Generate it!
config const numVertices = 1024 * 1024;
config const numEdges = 1024 * 1024 * 64;
config const edgeProbability = 0.01;
var hypergraph = new AdjListHyperGraph(numVertices, numEdges, new unmanaged Cyclic(startIdx=0));
var timer = new Timer();
timer.start();
generateErdosRenyi(hypergraph, edgeProbability);
timer.stop();
writeln("Generated ErdosRenyi with |V|=", numVertices, 
    ", |E|=", numEdges, ", P_E=", edgeProbability, " in ", timer.elapsed(), " seconds");


