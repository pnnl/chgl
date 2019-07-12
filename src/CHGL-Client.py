#
# This Client is a prototype that uses ZMQ to connect to a running
# Chapel server. This has been heavily inspired by Arkouda, the first
# project to take and use this approach. This is a prototype and is 
# intended as a brief proof-of-concept; the hope is that CHGL will 
# have integration with Arkouda at a later date. 
#

import zmq
import multiprocessing
from concurrent.futures import *
import argparse
import functools
import random


# Abstraction that represents an operation descriptor.
# Each operation will be converted into this.
class OpDescr:
    # Constant for sent and received operation descriptors
    SYN = 0x0 # Sent to server to initiate connection
    ACK = 0x1 # Received from server to verify connection
    CREATE_GRAPH = 0x2 # new AdjListHyperGraph(numVertices, numEdges)
    ADD_INCLUSION = 0x3 # graph.addInclusion
    GET_SIZE = 0x4 # graph.size
    def __init__(self, op, *args):
        self.op = op;
        self.args = args;

    def __repr__(self):
        return "{" + str(self.op) + ", " + str(self.args) + "}";

class CHGL:
    def __init__(self, connStr, numVertices, numEdges):
        # Aggregate operation descriptors to be sent to the client.
        # This ensures that we do not make all operations communication bound.
        self.aggregatedDescr = []
        # Use an executor for handling PUTs and GETs
        self. executor = ThreadPoolExecutor(max_workers=multiprocessing.cpu_count())
        print(zmq.zmq_version())

        # "protocol://server:port"
        pspStr = "tcp://" + connStr;
        print("Connecting to " + pspStr);

        self.context = zmq.Context()
        self.socket = self.context.socket(zmq.REQ) # request end of the zmq connection
        self.socket.connect(pspStr)

        # Send SYN and wait for ACK
        x = "{}:".format(OpDescr.SYN)
        self.socket.send_string(x)
        self.get_ack()
    
        x = "{}:{}:{}".format(OpDescr.CREATE_GRAPH, numVertices, numEdges)
        x.encode('ascii', 'ignore')
        self.socket.send_string(x)
        self.get_ack();

    def get_ack(self):
        ack = int.from_bytes(self.socket.recv(),  byteorder='little', signed=True) 
        assert ack == OpDescr.ACK, "Did not receive ACK; instead received " + str(ack);

    # Adds the vertex 'v' to hyperedge 'e'
    def addInclusion(self, v, e):
        self.aggregatedDescr.append(OpDescr(OpDescr.ADD_INCLUSION, v,e))
    
    # Obtains the size of the graph; returns a 'future'
    def size(self):
        self.flush() # Flush existing pending operations
        x = "{}:".format(OpDescr.GET_SIZE)
        x.encode('ascii', 'ignore')
        self.socket.send_string(x)
        return self.__get();

    # Private method to send a descritpr to the server. This will be aggregated
    # so that it can be handled in bulk.
    def __put(self, descr):
        self.aggregatedDescr.append(descr)


    # Flush the aggregation buffer of all pending operations
    def flush(self):
        # First perform coalescing...
        inclusionData = None
        for descr in self.aggregatedDescr:
            if descr.op == OpDescr.ADD_INCLUSION:
                if inclusionData is None:
                    inclusionData = set()
                inclusionData.add(tuple(descr.args))
        
        if inclusionData is not None:
            x = "{}:{}".format(OpDescr.ADD_INCLUSION, functools.reduce(lambda x,y: "{}:{}".format(x,y), inclusionData))
            x.encode('ascii', 'ignore')
            self.socket.send_string(x)
            self.get_ack();
        self.aggregatedDescr = []

    # Asynchronously handles both flushing and obtaining an object
    # This will flush the buffer first to ensure some kind of sequential consistency
    def __get(self):
        self.flush()
        return self.executor.submit(self.__getHelper)

    def __getHelper(self):
        ret = self.socket.recv()
        return int.from_bytes(ret, byteorder='little', signed=True)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Python interface for CHGL (W.I.P)')
    parser.add_argument('connStr', type=str, help='Connection string', default='localhost:5555')
    parser.add_argument('--numVertices', default=1024, help='Number of Vertices')
    parser.add_argument('--numEdges', default=1024, help='Number of Hyperedges')

    args = parser.parse_args()
    graph = CHGL(args.connStr, args.numVertices, args.numEdges)
    for i in range(int(args.numVertices)):
        for j in range(int(args.numEdges)):
            if random.random() <= 0.1:
                graph.addInclusion(i,j)
            
    print(graph.size().result())
