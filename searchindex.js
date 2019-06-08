Search.setIndex({envversion:46,filenames:["index","modules/src/AdjListHyperGraph","modules/src/AggregationBuffer","modules/src/BinReader","modules/src/Butterfly","modules/src/CHGL","modules/src/Components","modules/src/DynamicAggregationBuffer","modules/src/EquivalenceClasses","modules/src/FIFOChannel","modules/src/Generation","modules/src/Graph","modules/src/LocalAtomicObject","modules/src/Metrics","modules/src/PropertyMap","modules/src/SMetrics","modules/src/TerminationDetection","modules/src/Traversal","modules/src/Utilities","modules/src/Vectors","modules/src/Visualize","modules/src/WorkQueue","modules/src/testBTER"],objects:{"":{AdjListHyperGraph:[1,0,0,"-"],AggregationBuffer:[2,0,0,"-"],BinReader:[3,0,0,"-"],Butterfly:[4,0,0,"-"],CHGL:[5,0,0,"-"],Components:[6,0,0,"-"],DynamicAggregationBuffer:[7,0,0,"-"],EquivalenceClasses:[8,0,0,"-"],FIFOChannel:[9,0,0,"-"],Generation:[10,0,0,"-"],Graph:[11,0,0,"-"],LocalAtomicObject:[12,0,0,"-"],Metrics:[13,0,0,"-"],PropertyMap:[14,0,0,"-"],SMetrics:[15,0,0,"-"],TerminationDetection:[16,0,0,"-"],Traversal:[17,0,0,"-"],Utilities:[18,0,0,"-"],Vectors:[19,0,0,"-"],Visualize:[20,0,0,"-"],WorkQueue:[21,0,0,"-"],testBTER:[22,0,0,"-"]},"AdjListHyperGraph.AdjListHyperGraph":{destroy:[1,2,1,""],init:[1,2,1,""]},"AdjListHyperGraph.AdjListHyperGraphImpl":{"this":[1,2,1,""],addInclusion:[1,2,1,""],addInclusionBuffered:[1,2,1,""],collapse:[1,2,1,""],collapseEdges:[1,2,1,""],collapseSubsets:[1,2,1,""],collapseVertices:[1,2,1,""],degree:[1,2,1,""],eDescType:[1,3,1,""],eIndexType:[1,3,1,""],edges:[1,2,1,""],edgesDist:[1,2,1,""],edgesDomain:[1,2,1,""],flushBuffers:[1,2,1,""],getEdge:[1,2,1,""],getEdgeDegrees:[1,2,1,""],getEdges:[1,2,1,""],getInclusions:[1,2,1,""],getLocale:[1,2,1,""],getProperty:[1,2,1,""],getToplexes:[1,1,1,""],getVertex:[1,2,1,""],getVertexDegrees:[1,2,1,""],getVertices:[1,1,1,""],hasInclusion:[1,2,1,""],incidence:[1,1,1,""],init:[1,2,1,""],intersection:[1,1,1,""],intersectionSize:[1,2,1,""],isConnected:[1,2,1,""],localEdgesDomain:[1,2,1,""],localVerticesDomain:[1,2,1,""],numEdges:[1,2,1,""],numVertices:[1,2,1,""],removeDuplicates:[1,2,1,""],removeIsolatedComponents:[1,2,1,""],resizeEdges:[1,2,1,""],resizeVertices:[1,2,1,""],startAggregation:[1,2,1,""],stopAggregation:[1,2,1,""],these:[1,1,1,""],toEdge:[1,2,1,""],toVertex:[1,2,1,""],useAggregation:[1,2,1,""],vDescType:[1,3,1,""],vIndexType:[1,3,1,""],vertices:[1,2,1,""],verticesDist:[1,2,1,""],verticesDomain:[1,2,1,""],walk:[1,1,1,""]},"AdjListHyperGraph.Wrapper":{"null":[1,2,1,""],id:[1,3,1,""],idType:[1,3,1,""],nodeType:[1,3,1,""],readWriteThis:[1,2,1,""]},"AggregationBuffer.Aggregator":{"_value":[2,2,1,""],destroy:[2,2,1,""],init:[2,2,1,""],instance:[2,3,1,""],isInitialized:[2,2,1,""],msgType:[2,3,1,""],pid:[2,3,1,""]},"AggregationBuffer.AggregatorImpl":{aggregate:[2,2,1,""],deinit:[2,2,1,""],dsiGetPrivatizeData:[2,2,1,""],dsiPrivatize:[2,2,1,""],flushGlobal:[2,1,1,""],flushLocal:[2,1,1,""],getPrivatizedInstance:[2,2,1,""],init:[2,2,1,""],msgType:[2,3,1,""]},"AggregationBuffer.Buffer":{"this":[2,2,1,""],cap:[2,2,1,""],done:[2,2,1,""],getArray:[2,2,1,""],getDomain:[2,2,1,""],getPtr:[2,2,1,""],msgType:[2,3,1,""],readWriteThis:[2,2,1,""],size:[2,2,1,""],these:[2,1,1,""]},"Butterfly.AdjListHyperGraphImpl":{areAdjacentVertices:[4,2,1,""],edgesWithDegree:[4,1,1,""],getAdjacentVertices:[4,1,1,""],getEdgeButterflies:[4,2,1,""],getEdgeCaterpillars:[4,2,1,""],getEdgeMetamorphCoefs:[4,2,1,""],getEdgePerDegreeMetamorphosisCoefficients:[4,2,1,""],getInclusionMetamorphCoef:[4,2,1,""],getInclusionNumButterflies:[4,2,1,""],getInclusionNumCaterpillars:[4,2,1,""],getVertexButterflies:[4,2,1,""],getVertexCaterpillars:[4,2,1,""],getVertexMetamorphCoefs:[4,2,1,""],getVertexPerDegreeMetamorphosisCoefficients:[4,2,1,""],vertexHasNeighbor:[4,2,1,""],verticesWithDegree:[4,1,1,""]},"DynamicAggregationBuffer.DynamicAggregator":{"_value":[7,2,1,""],destroy:[7,2,1,""],init:[7,2,1,""],instance:[7,3,1,""],isInitialized:[7,2,1,""],msgType:[7,3,1,""],pid:[7,3,1,""]},"DynamicAggregationBuffer.DynamicAggregatorImpl":{agg:[7,3,1,""],aggregate:[7,2,1,""],dsiGetPrivatizeData:[7,2,1,""],dsiPrivatize:[7,2,1,""],dynamicDestBuffers:[7,3,1,""],flushGlobal:[7,1,1,""],flushLocal:[7,1,1,""],getPrivatizedInstance:[7,2,1,""],init:[7,2,1,""],msgType:[7,3,1,""],pid:[7,3,1,""]},"DynamicAggregationBuffer.DynamicBuffer":{acquire:[7,2,1,""],append:[7,2,1,""],arr:[7,3,1,""],dom:[7,3,1,""],done:[7,2,1,""],getArray:[7,2,1,""],lock:[7,3,1,""],msgType:[7,3,1,""],release:[7,2,1,""],size:[7,2,1,""]},"EquivalenceClasses.Equivalence":{add:[8,2,1,""],candidates:[8,3,1,""],candidatesDom:[8,3,1,""],cmpType:[8,3,1,""],eqclasses:[8,3,1,""],eqclassesDom:[8,3,1,""],getCandidates:[8,1,1,""],getEquivalenceClasses:[8,1,1,""],init:[8,2,1,""],keyType:[8,3,1,""],readWriteThis:[8,2,1,""],reduction:[8,2,1,""]},"EquivalenceClasses.ReduceEQClass":{accumulate:[8,2,1,""],accumulateOntoState:[8,2,1,""],clone:[8,2,1,""],cmpType:[8,3,1,""],combine:[8,2,1,""],generate:[8,2,1,""],identity:[8,2,1,""],init:[8,2,1,""],keyType:[8,3,1,""],value:[8,3,1,""]},"FIFOChannel.Channel":{close:[9,2,1,""],closed:[9,3,1,""],eltType:[9,3,1,""],flush:[9,2,1,""],inBuf:[9,3,1,""],inBufPending:[9,3,1,""],init:[9,2,1,""],isClosed:[9,2,1,""],other:[9,3,1,""],outBuf:[9,3,1,""],outBufClaimed:[9,3,1,""],outBufFilled:[9,3,1,""],outBufSize:[9,3,1,""],pair:[9,2,1,""],recv:[9,2,1,""],send:[9,2,1,""]},"Generation.DynamicArray":{"this":[10,2,1,""],arr:[10,3,1,""],dom:[10,3,1,""],init:[10,2,1,""]},"Generation.WorkInfo":{numOperations:[10,3,1,""],rngOffset:[10,3,1,""],rngSeed:[10,3,1,""]},"Graph.Graph":{"_value":[11,2,1,""],destroy:[11,2,1,""],init:[11,2,1,""],instance:[11,3,1,""],pid:[11,3,1,""]},"Graph.GraphImpl":{addEdge:[11,2,1,""],cacheValid:[11,3,1,""],cachedNeighborList:[11,3,1,""],cachedNeighborListDom:[11,3,1,""],degree:[11,2,1,""],edgeCounter:[11,3,1,""],flush:[11,2,1,""],getEdges:[11,1,1,""],hasEdge:[11,2,1,""],hg:[11,3,1,""],init:[11,2,1,""],insertAggregator:[11,3,1,""],intersection:[11,2,1,""],intersectionSize:[11,2,1,""],invalidateCache:[11,2,1,""],isCacheValid:[11,2,1,""],neighbors:[11,1,1,""],pid:[11,3,1,""],privatizedCachedNeighborListInstance:[11,3,1,""],privatizedCachedNeighborListPID:[11,3,1,""],simplify:[11,2,1,""],vDescType:[11,3,1,""],validateCache:[11,2,1,""]},"LocalAtomicObject.Foo":{print:[12,2,1,""],x:[12,3,1,""]},"LocalAtomicObject.LocalAtomicObject":{"_atomicVar":[12,3,1,""],atomicType:[12,3,1,""],compareExchange:[12,2,1,""],exchange:[12,2,1,""],objType:[12,3,1,""],read:[12,2,1,""],write:[12,2,1,""]},"PropertyMap.PropertyMap":{append:[14,2,1,""],clone:[14,2,1,""],edgePropertyType:[14,3,1,""],init:[14,2,1,""],isInitialized:[14,2,1,""],map:[14,3,1,""],vertexPropertyType:[14,3,1,""]},"PropertyMap.PropertyMapImpl":{addEdgeProperty:[14,2,1,""],addVertexProperty:[14,2,1,""],append:[14,2,1,""],ePropMap:[14,3,1,""],edgeProperties:[14,1,1,""],edgePropertyType:[14,3,1,""],getEdgeProperty:[14,2,1,""],getVertexProperty:[14,2,1,""],init:[14,2,1,""],numEdgeProperties:[14,2,1,""],numVertexProperties:[14,2,1,""],setEdgeProperty:[14,2,1,""],setVertexProperty:[14,2,1,""],vPropMap:[14,3,1,""],vertexProperties:[14,1,1,""],vertexPropertyType:[14,3,1,""]},"PropertyMap.PropertyMapping":{"lock$":[14,3,1,""],addProperty:[14,2,1,""],append:[14,2,1,""],arr:[14,3,1,""],dom:[14,3,1,""],getProperty:[14,2,1,""],init:[14,2,1,""],numProperties:[14,2,1,""],propertyType:[14,3,1,""],setProperty:[14,2,1,""],these:[14,1,1,""]},"SMetrics.WalkState":{"this":[15,2,1,""],append:[15,2,1,""],checkIntersection:[15,2,1,""],checkedIntersection:[15,2,1,""],checkingIntersection:[15,3,1,""],checkingNeighbor:[15,3,1,""],edgeType:[15,3,1,""],getNeighbor:[15,2,1,""],getTop:[15,2,1,""],hasProcessed:[15,2,1,""],init:[15,2,1,""],isCheckingIntersection:[15,2,1,""],isCheckingNeighbor:[15,2,1,""],neighbor:[15,3,1,""],sequence:[15,3,1,""],sequenceDom:[15,3,1,""],sequenceLength:[15,2,1,""],setNeighbor:[15,2,1,""],unsetNeighbor:[15,2,1,""],vertexType:[15,3,1,""]},"TerminationDetection.TerminationDetector":{"_value":[16,2,1,""],init:[16,2,1,""],instance:[16,3,1,""],pid:[16,3,1,""]},"TerminationDetection.TerminationDetectorImpl":{awaitTermination:[16,2,1,""],dsiGetPrivatizeData:[16,2,1,""],dsiPrivatize:[16,2,1,""],finished:[16,2,1,""],getPrivatizedInstance:[16,2,1,""],hasTerminated:[16,2,1,""],init:[16,2,1,""],pid:[16,3,1,""],started:[16,2,1,""],tasksFinished:[16,3,1,""],tasksStarted:[16,3,1,""]},"Traversal.list":{contains:[17,2,1,""]},"Utilities.Centralized":{init:[18,2,1,""],x:[18,3,1,""]},"Vectors.Vector":{"_dummy":[19,3,1,""],"this":[19,2,1,""],append:[19,2,1,""],clear:[19,2,1,""],eltType:[19,3,1,""],getArray:[19,2,1,""],init:[19,2,1,""],intersection:[19,2,1,""],intersectionSize:[19,2,1,""],size:[19,2,1,""],sort:[19,2,1,""],these:[19,1,1,""]},"Vectors.VectorImpl":{"this":[19,2,1,""],append:[19,2,1,""],arr:[19,3,1,""],cap:[19,3,1,""],clear:[19,2,1,""],dom:[19,3,1,""],getArray:[19,2,1,""],growthRate:[19,3,1,""],init:[19,2,1,""],intersection:[19,2,1,""],intersectionSize:[19,2,1,""],readWriteThis:[19,2,1,""],size:[19,2,1,""],sort:[19,2,1,""],sz:[19,3,1,""],these:[19,1,1,""]},"WorkQueue.Bag":{add:[21,2,1,""],deinit:[21,2,1,""],eltType:[21,3,1,""],init:[21,2,1,""],maxParallelSegmentSpace:[21,3,1,""],nextStartIdxDeq:[21,2,1,""],nextStartIdxEnq:[21,2,1,""],remove:[21,2,1,""],segments:[21,3,1,""],size:[21,2,1,""],startIdxDeq:[21,3,1,""],startIdxEnq:[21,3,1,""]},"WorkQueue.WorkQueue":{"_value":[21,2,1,""],init:[21,2,1,""],instance:[21,3,1,""],isInitialized:[21,2,1,""],pid:[21,3,1,""],workType:[21,3,1,""]},"WorkQueue.WorkQueueImpl":{addWork:[21,2,1,""],asyncTasks:[21,3,1,""],destBuffer:[21,3,1,""],dsiGetPrivatizeData:[21,2,1,""],dsiPrivatize:[21,2,1,""],dynamicDestBuffer:[21,3,1,""],flush:[21,2,1,""],flushLocal:[21,2,1,""],getPrivatizedInstance:[21,2,1,""],getWork:[21,2,1,""],globalSize:[21,2,1,""],init:[21,2,1,""],isEmpty:[21,2,1,""],isShutdown:[21,2,1,""],pid:[21,3,1,""],queue:[21,3,1,""],shutdown:[21,2,1,""],shutdownSignal:[21,3,1,""],size:[21,2,1,""],workType:[21,3,1,""]},AdjListHyperGraph:{"!=":[1,5,1,""],"+=":[1,5,1,""],"<":[1,5,1,""],"==":[1,5,1,""],">":[1,5,1,""],"_cast":[1,5,1,""],AdjListHyperGraph:[1,4,1,""],AdjListHyperGraphDisableAggregation:[1,6,1,""],AdjListHyperGraphDisablePrivatization:[1,6,1,""],AdjListHyperGraphImpl:[1,7,1,""],Wrapper:[1,4,1,""],fromAdjacencyList:[1,5,1,""],id:[1,5,1,""]},AggregationBuffer:{Aggregator:[2,4,1,""],AggregatorBufferSize:[2,6,1,""],AggregatorDebug:[2,6,1,""],AggregatorImpl:[2,7,1,""],AggregatorMaxBuffers:[2,6,1,""],Buffer:[2,7,1,""],UninitializedAggregator:[2,5,1,""],debug:[2,5,1,""]},BinReader:{DEBUG_BIN_READER:[3,6,1,""],binToGraph:[3,5,1,""],binToHypergraph:[3,5,1,""],debug:[3,5,1,""],main:[3,5,1,""]},Butterfly:{combinations:[4,5,1,""]},Components:{getEdgeComponentMappings:[6,5,1,""],getEdgeComponents:[6,9,1,""],getVertexComponents:[6,9,1,""]},DynamicAggregationBuffer:{DynamicAggregator:[7,4,1,""],DynamicAggregatorImpl:[7,7,1,""],DynamicBuffer:[7,7,1,""],UninitializedDynamicAggregator:[7,5,1,""]},EquivalenceClasses:{Equivalence:[8,7,1,""],ReduceEQClass:[8,7,1,""],main:[8,5,1,""]},FIFOChannel:{Channel:[9,7,1,""]},Generation:{"_round":[10,5,1,""],DynamicArray:[10,4,1,""],GenerationSeedOffset:[10,6,1,""],GenerationUseAggregation:[10,6,1,""],WorkInfo:[10,4,1,""],calculateWork:[10,5,1,""],computeAffinityBlocks:[10,5,1,""],distributedHistogram:[10,5,1,""],generateBTER:[10,5,1,""],generateChungLu:[10,5,1,""],generateChungLuAdjusted:[10,5,1,""],generateChungLuPreScanSMP:[10,5,1,""],generateChungLuSMP:[10,5,1,""],generateErdosRenyi:[10,5,1,""],generateErdosRenyiSMP:[10,5,1,""],histogram:[10,5,1,""],weightedRandomSample:[10,5,1,""]},Graph:{Graph:[11,4,1,""],GraphImpl:[11,7,1,""]},LocalAtomicObject:{Foo:[12,7,1,""],LocalAtomicObject:[12,4,1,""],main:[12,5,1,""]},Metrics:{edgeComponentSizeDistribution:[13,5,1,""],edgeDegreeDistribution:[13,5,1,""],vertexComponentSizeDistribution:[13,5,1,""],vertexDegreeDistribution:[13,5,1,""]},PropertyMap:{EmptyPropertyMap:[14,6,1,""],PropertyMap:[14,4,1,""],PropertyMapImpl:[14,7,1,""],PropertyMapping:[14,7,1,""]},SMetrics:{WalkState:[15,4,1,""],main:[15,5,1,""],walk:[15,9,1,""]},TerminationDetection:{"<=>":[16,5,1,""],TerminationDetector:[16,4,1,""],TerminationDetectorImpl:[16,7,1,""]},Traversal:{edgeBFS:[17,9,1,""],vertexBFS:[17,9,1,""]},Utilities:{"_globalIntRandomStream":[18,6,1,""],"_globalRealRandomStream":[18,6,1,""],"_intersection":[18,5,1,""],"_intersectionSize":[18,5,1,""],"_intersectionSizeAtLeast":[18,5,1,""],Centralized:[18,7,1,""],all:[18,5,1,""],any:[18,5,1,""],beginProfile:[18,5,1,""],chpl_comm_get_nb:[18,5,1,""],chpl_comm_nb_handle_t:[18,8,1,""],createBlock:[18,5,1,""],createCyclic:[18,5,1,""],endProfile:[18,5,1,""],getAddr:[18,5,1,""],getLines:[18,9,1,""],getLocale:[18,5,1,""],getLocaleID:[18,5,1,""],getNodeID:[18,5,1,""],get_nb:[18,5,1,""],intersection:[18,5,1,""],intersectionSize:[18,5,1,""],intersectionSizeAtLeast:[18,5,1,""],profileCommDiagnostics:[18,6,1,""],profileCommDiagnosticsVerbose:[18,6,1,""],profileVisualDebug:[18,6,1,""],randInt:[18,5,1,""],randReal:[18,5,1,""]},Vectors:{Vector:[19,7,1,""],VectorGrowthRate:[19,6,1,""],VectorImpl:[19,7,1,""]},Visualize:{main:[20,5,1,""],visualize:[20,5,1,""]},WorkQueue:{"<=>":[21,5,1,""],Bag:[21,7,1,""],UninitializedWorkQueue:[21,5,1,""],WorkQueue:[21,4,1,""],WorkQueueImpl:[21,7,1,""],WorkQueueNoAggregation:[21,6,1,""],WorkQueueUnlimitedAggregation:[21,6,1,""],doWorkLoop:[21,9,1,""],main:[21,5,1,""],workQueueInitialBlockSize:[21,6,1,""],workQueueMaxBlockSize:[21,6,1,""],workQueueMaxTightSpinCount:[21,6,1,""],workQueueMinTightSpinCount:[21,6,1,""],workQueueMinVelocityForFlush:[21,6,1,""]},testBTER:{dataPath:[22,6,1,""],ed_file:[22,6,1,""],edgeDegrees:[22,6,1,""],edgeMetamorphs:[22,6,1,""],em_file:[22,6,1,""],graph:[22,6,1,""],timer:[22,6,1,""],vd_file:[22,6,1,""],vertexDegrees:[22,6,1,""],vertexMetamorphs:[22,6,1,""],vm_file:[22,6,1,""]}},objnames:{"0":["chpl","module"," module"],"1":["chpl","itermethod"," itermethod"],"2":["chpl","method"," method"],"3":["chpl","attribute"," attribute"],"4":["chpl","record"," record"],"5":["chpl","function"," function"],"6":["chpl","data"," data"],"7":["chpl","class"," class"],"8":["chpl","type"," type"],"9":["chpl","iterfunction"," iterfunction"]},objtypes:{"0":"chpl:module","1":"chpl:itermethod","2":"chpl:method","3":"chpl:attribute","4":"chpl:record","5":"chpl:function","6":"chpl:data","7":"chpl:class","8":"chpl:type","9":"chpl:iterfunction"},terms:{"_atomicvar":12,"_cast":1,"_dummi":19,"_edgesdomain":1,"_globalintrandomstream":18,"_globalrealrandomstream":18,"_intersect":18,"_intersections":18,"_intersectionsizeatleast":18,"_iteratorrecord":[18,19],"_need_":1,"_not_":1,"_pid":11,"_propertymap":1,"_round":10,"_thi":1,"_v1":11,"_v2":11,"_valu":[2,7,11,16,17,21],"_verticesdomain":1,"boolean":4,"case":21,"class":[1,2,7,8,9,11,12,14,16,18,19,21],"const":[1,2,10,14,18,19,21,22],"default":10,"export":20,"int":[2,4,6,7,9,10,11,14,18,19,21,22],"new":[1,14,21],"null":1,"return":[1,2,4,6],"throw":[1,3,20],"true":[4,10,14],"var":[1,2,7,8,9,10,11,12,14,15,16,18,19,21,22],"void":7,"while":1,about:16,access:1,accumul:8,accumulateontost:8,acquir:7,across:9,act:1,add:[1,8,21],addedg:11,addedgeproperti:14,addinclus:1,addinclusionbuff:1,addproperti:14,addr:18,addvertexproperti:14,addwork:21,adjac:1,adjlisthypergraph:0,adjlisthypergraphdisableaggreg:1,adjlisthypergraphdisableprivat:1,adjlisthypergraphimpl:[1,4],advis:1,after:[2,17],agg:7,aggreg:[1,2,7],aggregationbuff:0,aggregatorbuffers:2,aggregatordebug:2,aggregatorimpl:2,aggregatormaxbuff:2,aliv:16,all:[1,4,6,7,10,16,18],alloc:1,allow:1,also:1,ani:[1,4,18],anoth:16,append:[7,14,15,19],appendexpr:22,approach:21,areadjacentvertic:4,arg:[1,2,3],argument:[1,4,10],arr:[7,10,14,18,19],arrai:[1,4],associ:4,assumpt:1,asynctask:21,atomicatomictyp:12,atomicbool:[7,9,11,21],atomicint:[9,16],atomictyp:12,avoid:7,awaittermin:16,back:2,background:7,bag:21,bagseg:21,balanc:21,becom:16,been:16,befor:16,begin:16,beginprofil:18,behavior:2,benefit:16,best:21,between:10,bidirect:1,binread:[0,1],bintograph:3,bintohypergraph:3,bipartit:1,block:[1,10],bool:[1,14,15,16,21],both:[1,16,17],boundingbox:1,breadth:17,buf:7,buffer:[2,7],bulk:9,butterfli:0,c_int:18,c_ptr:9,c_void_ptr:18,cachedneighborlist:11,cachedneighborlistdom:11,cachevalid:11,calcuat:4,calcul:4,calculatework:10,call08:22,call:[1,7],can:[4,9,16,17],candid:8,candidatesdom:8,cap:[2,19],cardin:1,cast:4,caus:1,central:18,certain:1,chanc:21,channel:9,chapel:[0,16],check:4,checkedintersect:15,checkingintersect:15,checkingneighbor:15,checkintersect:15,chgl:0,child:16,chpl__processoratomictyp:21,chpl__tuple_arg_temp:1,chpl_comm_get_nb:18,chpl_comm_nb_handle_t:18,chpl_localeid_t:18,chpl_nodeid_t:18,chunksiz:18,clear:19,clone:[8,14],close:9,cmptype:8,code:17,coeffici:4,coforal:1,collaps:1,collapseedg:1,collapsesubset:1,collapsevertic:1,combin:[4,8],come:7,commid:18,common:4,commun:[1,9],compar:4,compareexchang:12,compon:0,comput:10,computeaffinityblock:10,config:[1,2,3,10,18,19,21,22],contain:[1,2,4,17],content:0,copi:[1,2],count:[4,6],counter:16,couponcollector:10,creat:[1,7,10,16],createblock:18,createcycl:18,csc:1,csr:1,current:[1,2,15],cut:1,cycl:4,cyclic:1,cylc:4,data:[2,7,9,16,22],datapath:22,dataset:3,debug:[2,3],debug_bin_read:3,decrement:16,defaultdist:1,defaultrectangulardist:1,defin:4,degre:[1,4,10,11],deinit:[2,21],delet:1,delimitor:1,depth:17,dequeu:21,desc:1,desir:[1,4,10],desired_edge_degre:10,desired_vertex_degre:10,desirededgedegre:10,desiredvertexdegre:10,destbuff:21,destroi:[1,2,7,11,16],detect:[16,17],detector:16,determin:[1,16],disabl:1,distributedhistogram:10,dom:[7,10,14,18,19],domain:[8,14,18],done:[2,7,17],dosomethingto:16,dot:20,doworkloop:21,dsigetprivatizedata:[2,7,16,21],dsiprivat:[2,7,16,21],duplic:4,dynam:7,dynamicaggreg:7,dynamicaggregationbuff:0,dynamicaggregatorimpl:7,dynamicarrai:10,dynamicbuff:7,dynamicdestbuff:[7,21],each:[4,16,21],easi:[1,16],ed_fil:22,eddom:10,edegseq:10,edegseqdom:10,edesc:1,edesctyp:[1,4,17],edg:[1,4,10,15],edgebf:17,edgecomponentsizedistribut:13,edgecount:11,edgedegre:22,edgedegreedistribut:13,edgedomain:10,edgemap:1,edgemetamorph:22,edgeproperti:14,edgepropertytyp:[1,14],edgescan:10,edgesdist:1,edgesdomain:[1,10],edgesmap:[1,11],edgeswithdegre:4,edgetyp:15,edgewrappereindextyp:1,effort:21,eindextyp:1,element:[1,21],els:11,elt:[9,17,19,21],elttyp:[9,17,19,21],em_fil:22,emc:10,emcdom:10,emptypropertymap:14,enabl:1,endprofil:18,enough:16,enqueu:21,entir:10,epropmap:14,eproptyp:1,eqclass:8,eqclassesdom:8,equival:[8,16],equivalenceclass:0,erdo:10,even:16,evenli:21,everi:[1,4],everyth:11,exampl:[1,16],exchang:12,exist:4,expand:2,expectedobj:12,experi:2,explicit:[1,7],explicitli:[1,7,9],fals:[1,2,3,4,14,18],fetch:4,few:1,fifo:9,fifochannel:0,file:[1,18],filenam:[1,20],fill:9,find:21,finish:16,first:[4,17],flush:[1,7,9,11,21],flushbuff:1,flushglob:[2,7],flushloc:[2,7,21],followthi:[1,2],foo:12,foral:[1,11],format:20,forward:[1,11],from:[1,10],fromadjacencylist:1,furthermor:21,futur:18,gener:[0,8],generatebt:[10,22],generatechunglu:10,generatechungluadjust:10,generatechungluprescansmp:10,generatechunglusmp:10,generateerdosrenyi:10,generateerdosrenyismp:10,generationseedoffset:10,generationuseaggreg:10,get:7,get_nb:18,getaddr:18,getadjacentvertic:4,getarrai:[2,7,19],getcandid:8,getdomain:2,getedg:[1,11],getedgebutterfli:4,getedgecaterpillar:4,getedgecompon:6,getedgecomponentmap:6,getedgedegre:1,getedgemetamorphcoef:4,getedgeperdegreemetamorphosiscoeffici:4,getedgeproperti:14,getequivalenceclass:8,getinclus:1,getinclusionmetamorphcoef:4,getinclusionnumbutterfli:4,getinclusionnumcaterpillar:4,getlin:18,getlocal:[1,18],getlocaleid:18,getneighbor:15,getnodeid:18,getprivatizedinst:[1,2,7,16,21],getproperti:[1,14],getptr:2,gettop:15,gettoplex:1,getvertex:1,getvertexbutterfli:4,getvertexcaterpillar:4,getvertexcompon:6,getvertexdegre:1,getvertexmetamorphcoef:4,getvertexperdegreemetamorphosiscoeffici:4,getvertexproperti:14,getvertic:1,getwork:21,given:[1,4,16],globals:21,graph:[0,1,6,10],graphimpl:11,graphviz:20,growthrat:19,half:1,handl:7,hasedg:11,hasinclus:1,hasprocess:15,hastermin:16,have:[1,4,7,16,17,21],help:21,henc:[1,16],here:21,high:18,higher:16,highest:4,histogram:10,hold:7,hyperedg:[1,10,15],ideal:21,ident:8,idtyp:1,idx:[1,2,10,15,18,19],implement:[11,16,17],inbuf:9,inbufpend:9,incid:1,includ:[4,10],inclus:4,inclusionstoadd:10,increas:[16,21],increment:16,index:[0,1,2,4],init:[1,2,7,8,9,10,11,14,15,16,18,19,21],input:4,insertaggreg:11,insid:1,instanc:[1,2,7,11,16,21],instead:1,integ:4,integr:[1,2,4,10,11,15,18,19],intent:16,intersect:[1,11,18,19],intersections:[1,11,18,19],intersectionsizeatleast:18,invalidatecach:11,invok:2,involv:16,iscachevalid:11,ischeckingintersect:15,ischeckingneighbor:15,isclos:9,isconnect:1,isempti:[14,21],isiniti:[2,7,14,21],isshutdown:21,issu:7,item:10,iter:[1,2,4,6,7,8,11,14,15,17,18,19,21],iterkind:[1,2,4,7,8,11,14,15,18,19,21],itself:1,just:16,kei:8,keytyp:8,keytypeequival:8,keytypeequivalencecmptyp:8,larg:1,least:4,left:16,len:9,less:21,level:10,like:[1,21],list:[1,4,17],loc:[2,7,21],local:[1,2,7,9,10,16,21],localatomicobject:0,localedgesdomain:1,localespac:7,localverticesdomain:1,locat:16,locid:[2,7,21],lock:[7,14],loop:1,low:18,lower:16,main:[3,8,12,15,20,21],maintain:1,make:[7,16],makerandomstream:18,manag:15,map:[1,11,14],matrix:1,maxbackoff:16,maximum:4,maxparallelsegmentspac:21,maxtaskpar:21,memori:1,metamorphosi:4,method:2,metric:0,minbackoff:16,modul:0,msg:[2,7],msgtype:[2,7],multbackoff:16,multipl:[1,9,16],must:[2,10,16],mutabl:10,naiv:1,name:1,narg:[2,3],need:[7,17],neighbor:[1,4,11,15],neighborlist:4,never:7,newobj:12,nextstartidxdeq:21,nextstartidxenq:21,node:[16,18],nodedata:1,nodetyp:1,nodetypewrapp:1,nodetypewrapperidtyp:1,nop:1,normal:1,note:1,now:1,num_edg:10,num_vertic:10,numaggregatedwork:21,number:[1,4,6,10],numedg:[1,11],numedgeproperti:14,numer:4,numinclus:10,numoper:10,numproperti:14,numrandom:10,numvertexproperti:14,numvertic:[1,11],object:[1,4],objtyp:12,obtain:1,occur:16,onc:[1,16],onli:1,open:7,oper:1,optim:1,origin:1,other:[1,2,7,8,9,10,11,14,15,16,19,21],our:[15,21],out:20,outbuf:9,outbufclaim:9,outbuffil:9,outbufs:9,over:[2,6,10],overhead:1,overlap:21,overrid:19,own:[7,14,16],page:0,pair:9,param:[1,2,3,4,6,7,8,10,11,14,15,18,19,21],parent:16,partial:7,particip:1,pass:1,pattern:17,per:[1,4],perform:[1,10,16],pid:[2,7,11,16,21],placement:21,pool:2,possibl:[4,7],print:12,privat:[1,16],privatizedcachedneighborlistinst:11,privatizedcachedneighborlistpid:11,probabl:10,probtabl:10,proc:[1,2,3,4,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21],profilecommdiagnost:18,profilecommdiagnosticsverbos:18,profilevisualdebug:18,progress:[1,7],properti:[1,14],propertymap:[0,1],propertymapimpl:14,propertytyp:14,propmap:1,prototyp:11,provid:1,pure:1,queri:4,queue:21,raddr:18,randint:18,randreal:18,randvalu:10,rang:[4,18],rather:1,read:[1,12],reader:1,readwritethi:[1,2,8,19],real:[4,10,18,19,22],record:[1,2,7,10,11,12,14,15,16,21],recv:9,recycl:2,reduc:16,reduceeqclass:8,reducescanop:8,reduct:[8,16],ref:[1,2,8,10,15,16,18,19,21],refer:1,regard:1,releas:7,remot:[2,16],remov:21,removedupl:1,removeisolatedcompon:1,renyi:10,repres:[4,15],request:7,requir:17,resizeedg:1,resizevertic:1,respect:[1,16],result:1,right:16,rng:18,rngoffset:10,rngseed:10,robin:21,round:21,safe:1,same:[1,16],search:[0,17],second:4,segment:21,self:2,send:[7,9],sent:[7,9],separ:1,sequenc:[1,10,15],sequencedom:15,sequencelength:15,sequenti:1,serv:1,set:[1,10],setedgeproperti:14,setneighbor:15,setproperti:14,setvertexproperti:14,sever:1,shallow:1,share:[1,4],should:[1,11],shutdown:21,shutdownsign:21,similar:1,simpl:11,simplifi:11,size:[1,2,7,15,18,19,21],size_t:18,smetric:0,someth:1,sort:[10,19],spawn:16,start:16,startaggreg:1,startidx:[1,18],startidxdeq:21,startidxenq:21,state:[8,15],statement:1,stopaggreg:1,storag:1,store:[1,4],strictli:1,string:[1,3,14,18],subject:2,subset:10,support:11,sync:14,tag:[1,2,4,7,8,11,14,15,18,19,21],target:4,targetloc:10,targetlocal:[2,10],task:[1,7,16],tasksfinish:16,tasksstart:16,term:[1,16],termin:[16,17],terminationdetect:0,terminationdetector:[16,21],terminationdetectorimpl:16,test:4,testbter:0,than:[1,16],thei:[1,21],them:1,thi:[1,2,4,7,8,10,14,15,17,19],thread:1,time:[1,16],timer:22,todo:2,toedg:1,total:6,tovertex:1,travers:0,truth:4,twice:16,two:[1,4,10,16],type:[1,2,4,7,8,9,11,12,14,15,18,19,21],typeindex:18,uint:[12,21],undefin:2,under:4,underli:11,uniform:11,uninitializedaggreg:[2,7,11,21],uninitializeddynamicaggreg:[7,21],uninitializedworkqueu:21,unmanag:[1,2,7,8,9,11,14,16,21],unsetneighbor:15,until:7,updat:16,useaggreg:1,user:[1,2,7],util:0,validatecach:11,valu:[4,8],vd_file:22,vddom:10,vdebug:18,vdebugnam:18,vdegseq:10,vdegseqdom:10,vdesc:1,vdesctyp:[1,4,11,17],vector:[0,11],vectorgrowthr:19,vectorimpl:19,veri:16,version:1,vertex:[1,4,10,15],vertexbf:17,vertexcomponentsizedistribut:13,vertexdegre:22,vertexdegreedistribut:13,vertexdomain:10,vertexhasneighbor:4,vertexmap:1,vertexmetamorph:22,vertexproperti:14,vertexpropertytyp:[1,14],vertexpropertytypepropertymap:14,vertexpropertytypepropertymapimpl:14,vertexpropertytypepropertymapimpledgepropertytyp:14,vertexscan:10,vertextyp:15,vertexwrappervindextyp:1,vertic:[1,4,6,10],verticesdist:1,verticesdomain:[1,10,11],verticesmap:[1,11],verticeswithdegre:4,via:1,vindextyp:1,visit:16,visitor:17,visual:0,vm_file:22,vmc:10,vmcdom:10,vpropmap:14,vproptypepropertymap:1,wai:1,walk:[1,15],walkstat:15,warn:1,weightedrandomsampl:10,well:15,when:[7,9],where:[4,21],whether:[1,16],which:[1,10,16],within:[1,4],without:[1,4],work:[1,21],workinfo:10,workqueu:0,workqueueimpl:21,workqueueinitialblocks:21,workqueuemaxblocks:21,workqueuemaxtightspincount:21,workqueuemintightspincount:21,workqueueminvelocityforflush:21,workqueuenoaggreg:21,workqueueunlimitedaggreg:21,worktyp:21,would:1,wq1:21,wq2:21,wrapper:1,write:12,yield:4,you:1},titles:["chpldoc documentation","AdjListHyperGraph","AggregationBuffer","BinReader","Butterfly","CHGL","Components","DynamicAggregationBuffer","EquivalenceClasses","FIFOChannel","Generation","Graph","LocalAtomicObject","Metrics","PropertyMap","SMetrics","TerminationDetection","Traversal","Utilities","Vectors","Visualize","WorkQueue","testBTER"],titleterms:{adjlisthypergraph:1,aggregationbuff:2,binread:3,butterfli:4,chgl:5,chpldoc:0,compon:6,distribut:1,document:0,dual:1,dynamicaggregationbuff:7,equivalenceclass:8,fifochannel:9,gener:10,global:1,graph:11,hypergraph:1,indic:0,localatomicobject:12,metric:13,parallel:1,propertymap:14,smetric:15,tabl:0,terminationdetect:16,testbter:22,travers:17,usag:1,util:18,vector:19,view:1,visual:20,workqueu:21}})