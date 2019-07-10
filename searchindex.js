Search.setIndex({envversion:46,filenames:["index","modules/src/AdjListHyperGraph","modules/src/AggregationBuffer","modules/src/BinReader","modules/src/Butterfly","modules/src/CHGL","modules/src/CHGL-Server","modules/src/DynamicAggregationBuffer","modules/src/EquivalenceClasses","modules/src/Generation","modules/src/Graph","modules/src/Metrics","modules/src/PropertyMaps","modules/src/TerminationDetection","modules/src/Traversal","modules/src/Utilities","modules/src/Vectors","modules/src/Visualize","modules/src/WorkQueue"],objects:{"":{"CHGL-Server":[6,0,0,"-"],AdjListHyperGraph:[1,0,0,"-"],AggregationBuffer:[2,0,0,"-"],BinReader:[3,0,0,"-"],Butterfly:[4,0,0,"-"],CHGL:[5,0,0,"-"],DynamicAggregationBuffer:[7,0,0,"-"],EquivalenceClasses:[8,0,0,"-"],Generation:[9,0,0,"-"],Graph:[10,0,0,"-"],Metrics:[11,0,0,"-"],PropertyMaps:[12,0,0,"-"],TerminationDetection:[13,0,0,"-"],Traversal:[14,0,0,"-"],Utilities:[15,0,0,"-"],Vectors:[16,0,0,"-"],Visualize:[17,0,0,"-"],WorkQueue:[18,0,0,"-"]},"AdjListHyperGraph.AdjListHyperGraph":{destroy:[1,1,1,""],init:[1,1,1,""]},"AdjListHyperGraph.AdjListHyperGraphImpl":{"this":[1,1,1,""],addInclusion:[1,1,1,""],addInclusionBuffered:[1,1,1,""],collapse:[1,1,1,""],collapseEdges:[1,1,1,""],collapseSubsets:[1,1,1,""],collapseVertices:[1,1,1,""],degree:[1,1,1,""],eDescType:[1,2,1,""],eIndexType:[1,2,1,""],edgesDomain:[1,1,1,""],flushBuffers:[1,1,1,""],getEdgeDegrees:[1,1,1,""],getEdges:[1,1,1,""],getInclusions:[1,1,1,""],getLocale:[1,1,1,""],getProperty:[1,1,1,""],getToplexes:[1,7,1,""],getVertexDegrees:[1,1,1,""],getVertices:[1,7,1,""],hasInclusion:[1,1,1,""],incidence:[1,7,1,""],intersection:[1,7,1,""],intersectionSize:[1,1,1,""],isConnected:[1,1,1,""],numEdges:[1,1,1,""],numVertices:[1,1,1,""],removeDuplicates:[1,1,1,""],removeIsolatedComponents:[1,1,1,""],startAggregation:[1,1,1,""],stopAggregation:[1,1,1,""],these:[1,7,1,""],toEdge:[1,1,1,""],toVertex:[1,1,1,""],vDescType:[1,2,1,""],vIndexType:[1,2,1,""],verticesDomain:[1,1,1,""],walk:[1,7,1,""]},"AdjListHyperGraph.Wrapper":{"null":[1,1,1,""],id:[1,2,1,""],idType:[1,2,1,""],nodeType:[1,2,1,""],readWriteThis:[1,1,1,""]},"AggregationBuffer.Aggregator":{"_value":[2,1,1,""],destroy:[2,1,1,""],init:[2,1,1,""],instance:[2,2,1,""],isInitialized:[2,1,1,""],msgType:[2,2,1,""],pid:[2,2,1,""]},"AggregationBuffer.AggregatorImpl":{aggregate:[2,1,1,""],deinit:[2,1,1,""],dsiGetPrivatizeData:[2,1,1,""],dsiPrivatize:[2,1,1,""],flushGlobal:[2,7,1,""],flushLocal:[2,7,1,""],getPrivatizedInstance:[2,1,1,""],init:[2,1,1,""],msgType:[2,2,1,""],size:[2,1,1,""]},"AggregationBuffer.Buffer":{"this":[2,1,1,""],cap:[2,1,1,""],done:[2,1,1,""],getArray:[2,1,1,""],getDomain:[2,1,1,""],getPtr:[2,1,1,""],msgType:[2,2,1,""],readWriteThis:[2,1,1,""],size:[2,1,1,""],these:[2,7,1,""]},"Butterfly.AdjListHyperGraphImpl":{areAdjacentVertices:[4,1,1,""],edgesWithDegree:[4,7,1,""],getAdjacentVertices:[4,7,1,""],getEdgeButterflies:[4,1,1,""],getEdgeCaterpillars:[4,1,1,""],getEdgeMetamorphCoefs:[4,1,1,""],getEdgePerDegreeMetamorphosisCoefficients:[4,1,1,""],getInclusionMetamorphCoef:[4,1,1,""],getInclusionNumButterflies:[4,1,1,""],getInclusionNumCaterpillars:[4,1,1,""],getVertexButterflies:[4,1,1,""],getVertexCaterpillars:[4,1,1,""],getVertexMetamorphCoefs:[4,1,1,""],getVertexPerDegreeMetamorphosisCoefficients:[4,1,1,""],vertexHasNeighbor:[4,1,1,""],verticesWithDegree:[4,7,1,""]},"CHGL-Server":{ACK:[6,4,1,""],ADD_INCLUSION:[6,4,1,""],CREATE_GRAPH:[6,4,1,""],GET_SIZE:[6,4,1,""],SYN:[6,4,1,""],ServerPort:[6,4,1,""],get_hostname:[6,6,1,""],main:[6,6,1,""]},"DynamicAggregationBuffer.DynamicAggregator":{"_value":[7,1,1,""],destroy:[7,1,1,""],init:[7,1,1,""],instance:[7,2,1,""],isInitialized:[7,1,1,""],msgType:[7,2,1,""],pid:[7,2,1,""]},"DynamicAggregationBuffer.DynamicAggregatorImpl":{agg:[7,2,1,""],aggregate:[7,1,1,""],deinit:[7,1,1,""],dsiGetPrivatizeData:[7,1,1,""],dsiPrivatize:[7,1,1,""],dynamicDestBuffers:[7,2,1,""],flushGlobal:[7,7,1,""],flushLocal:[7,7,1,""],getPrivatizedInstance:[7,1,1,""],init:[7,1,1,""],msgType:[7,2,1,""],pid:[7,2,1,""],size:[7,1,1,""]},"DynamicAggregationBuffer.DynamicBuffer":{acquire:[7,1,1,""],append:[7,1,1,""],arr:[7,2,1,""],dom:[7,2,1,""],done:[7,1,1,""],getArray:[7,1,1,""],lock:[7,2,1,""],msgType:[7,2,1,""],release:[7,1,1,""],size:[7,1,1,""]},"EquivalenceClasses.Equivalence":{add:[8,1,1,""],candidates:[8,2,1,""],candidatesDom:[8,2,1,""],cmpType:[8,2,1,""],eqclasses:[8,2,1,""],eqclassesDom:[8,2,1,""],getCandidates:[8,7,1,""],getEquivalenceClasses:[8,7,1,""],init:[8,1,1,""],keyType:[8,2,1,""],readWriteThis:[8,1,1,""],reduction:[8,1,1,""]},"EquivalenceClasses.ReduceEQClass":{accumulate:[8,1,1,""],accumulateOntoState:[8,1,1,""],clone:[8,1,1,""],cmpType:[8,2,1,""],combine:[8,1,1,""],generate:[8,1,1,""],identity:[8,1,1,""],init:[8,1,1,""],keyType:[8,2,1,""],value:[8,2,1,""]},"Generation.DynamicArray":{"this":[9,1,1,""],arr:[9,2,1,""],dom:[9,2,1,""],init:[9,1,1,""]},"Generation.WorkInfo":{numOperations:[9,2,1,""],rngOffset:[9,2,1,""],rngSeed:[9,2,1,""]},"Graph.Graph":{"_value":[10,1,1,""],destroy:[10,1,1,""],init:[10,1,1,""],instance:[10,2,1,""],pid:[10,2,1,""]},"Graph.GraphImpl":{addEdge:[10,1,1,""],cacheValid:[10,2,1,""],cachedNeighborList:[10,2,1,""],cachedNeighborListDom:[10,2,1,""],degree:[10,1,1,""],edgeCounter:[10,2,1,""],flush:[10,1,1,""],getEdges:[10,7,1,""],hasEdge:[10,1,1,""],hg:[10,2,1,""],init:[10,1,1,""],insertAggregator:[10,2,1,""],intersection:[10,1,1,""],intersectionSize:[10,1,1,""],invalidateCache:[10,1,1,""],isCacheValid:[10,1,1,""],neighbors:[10,7,1,""],pid:[10,2,1,""],privatizedCachedNeighborListInstance:[10,2,1,""],privatizedCachedNeighborListPID:[10,2,1,""],simplify:[10,1,1,""],vDescType:[10,2,1,""],validateCache:[10,1,1,""]},"Metrics.EdgeSorter":{graph:[11,2,1,""],init:[11,1,1,""],key:[11,1,1,""]},"Metrics.VertexSorter":{graph:[11,2,1,""],init:[11,1,1,""],key:[11,1,1,""]},"PropertyMaps.PropertyMap":{"_value":[12,1,1,""],clone:[12,1,1,""],destroy:[12,1,1,""],init:[12,1,1,""],isInitialized:[12,1,1,""],mapperType:[12,2,1,""],propertyType:[12,2,1,""]},"PropertyMaps.PropertyMapImpl":{append:[12,1,1,""],create:[12,1,1,""],flushGlobal:[12,1,1,""],flushLocal:[12,1,1,""],getProperty:[12,1,1,""],init:[12,1,1,""],localProperties:[12,7,1,""],lock:[12,2,1,""],mapper:[12,2,1,""],numProperties:[12,1,1,""],numPropertiesGlobal:[12,1,1,""],propertyType:[12,2,1,""],setProperty:[12,1,1,""],these:[12,7,1,""]},"TerminationDetection.TerminationDetector":{"_value":[13,1,1,""],destroy:[13,1,1,""],init:[13,1,1,""],instance:[13,2,1,""],pid:[13,2,1,""]},"TerminationDetection.TerminationDetectorImpl":{awaitTermination:[13,1,1,""],dsiGetPrivatizeData:[13,1,1,""],dsiPrivatize:[13,1,1,""],finished:[13,1,1,""],getPrivatizedInstance:[13,1,1,""],getStatistics:[13,1,1,""],hasTerminated:[13,1,1,""],init:[13,1,1,""],pid:[13,2,1,""],started:[13,1,1,""],tasksFinished:[13,2,1,""],tasksStarted:[13,2,1,""]},"Utilities.ArrayRef":{"_value":[15,1,1,""],init:[15,1,1,""],instance:[15,2,1,""],pid:[15,2,1,""]},"Utilities.Centralized":{init:[15,1,1,""],x:[15,2,1,""]},"Vectors.Vector":{"_dummy":[16,2,1,""],"this":[16,1,1,""],append:[16,1,1,""],clear:[16,1,1,""],eltType:[16,2,1,""],getArray:[16,1,1,""],init:[16,1,1,""],intersection:[16,1,1,""],intersectionSize:[16,1,1,""],size:[16,1,1,""],sort:[16,1,1,""],these:[16,7,1,""]},"Vectors.VectorImpl":{"this":[16,1,1,""],append:[16,1,1,""],arr:[16,2,1,""],cap:[16,2,1,""],clear:[16,1,1,""],dom:[16,2,1,""],getArray:[16,1,1,""],growthRate:[16,2,1,""],init:[16,1,1,""],intersection:[16,1,1,""],intersectionSize:[16,1,1,""],readWriteThis:[16,1,1,""],size:[16,1,1,""],sort:[16,1,1,""],sz:[16,2,1,""],these:[16,7,1,""]},"WorkQueue.Bag":{add:[18,1,1,""],deinit:[18,1,1,""],eltType:[18,2,1,""],init:[18,1,1,""],maxParallelSegmentSpace:[18,2,1,""],nextStartIdxDeq:[18,1,1,""],nextStartIdxEnq:[18,1,1,""],remove:[18,1,1,""],segments:[18,2,1,""],size:[18,1,1,""],startIdxDeq:[18,2,1,""],startIdxEnq:[18,2,1,""]},"WorkQueue.WorkQueue":{"_value":[18,1,1,""],init:[18,1,1,""],instance:[18,2,1,""],isInitialized:[18,1,1,""],pid:[18,2,1,""],workType:[18,2,1,""]},"WorkQueue.WorkQueueImpl":{addWork:[18,1,1,""],asyncTasks:[18,2,1,""],destBuffer:[18,2,1,""],destroy:[18,1,1,""],dsiGetPrivatizeData:[18,1,1,""],dsiPrivatize:[18,1,1,""],dynamicDestBuffer:[18,2,1,""],flush:[18,1,1,""],flushLocal:[18,1,1,""],getPrivatizedInstance:[18,1,1,""],getWork:[18,1,1,""],globalSize:[18,1,1,""],init:[18,1,1,""],isEmpty:[18,1,1,""],isShutdown:[18,1,1,""],pid:[18,2,1,""],queue:[18,2,1,""],shutdown:[18,1,1,""],shutdownSignal:[18,2,1,""],size:[18,1,1,""],workPending:[18,1,1,""],workType:[18,2,1,""]},AdjListHyperGraph:{"!=":[1,6,1,""],"+=":[1,6,1,""],"<":[1,6,1,""],"==":[1,6,1,""],">":[1,6,1,""],"_cast":[1,6,1,""],AdjListHyperGraph:[1,5,1,""],AdjListHyperGraphDisableAggregation:[1,4,1,""],AdjListHyperGraphDisablePrivatization:[1,4,1,""],AdjListHyperGraphImpl:[1,3,1,""],Wrapper:[1,5,1,""],fromAdjacencyList:[1,6,1,""],id:[1,6,1,""]},AggregationBuffer:{Aggregator:[2,5,1,""],AggregatorBufferSize:[2,4,1,""],AggregatorDebug:[2,4,1,""],AggregatorImpl:[2,3,1,""],AggregatorMaxBuffers:[2,4,1,""],Buffer:[2,3,1,""],UninitializedAggregator:[2,6,1,""],debug:[2,6,1,""]},BinReader:{DEBUG_BIN_READER:[3,4,1,""],binToGraph:[3,6,1,""],binToHypergraph:[3,6,1,""],debug:[3,6,1,""],main:[3,6,1,""],numEdgesPresent:[3,4,1,""]},Butterfly:{combinations:[4,6,1,""]},DynamicAggregationBuffer:{DynamicAggregator:[7,5,1,""],DynamicAggregatorImpl:[7,3,1,""],DynamicBuffer:[7,3,1,""],UninitializedDynamicAggregator:[7,6,1,""]},EquivalenceClasses:{Equivalence:[8,3,1,""],ReduceEQClass:[8,3,1,""],main:[8,6,1,""]},Generation:{"_round":[9,6,1,""],DynamicArray:[9,5,1,""],GenerationSeedOffset:[9,4,1,""],GenerationUseAggregation:[9,4,1,""],WorkInfo:[9,5,1,""],calculateWork:[9,6,1,""],computeAffinityBlocks:[9,6,1,""],distributedHistogram:[9,6,1,""],generateBTER:[9,6,1,""],generateChungLu:[9,6,1,""],generateChungLuAdjusted:[9,6,1,""],generateChungLuPreScanSMP:[9,6,1,""],generateChungLuSMP:[9,6,1,""],generateErdosRenyi:[9,6,1,""],generateErdosRenyiSMP:[9,6,1,""],histogram:[9,6,1,""],weightedRandomSample:[9,6,1,""]},Graph:{Graph:[10,5,1,""],GraphImpl:[10,3,1,""]},Metrics:{EdgeSorter:[11,5,1,""],VertexSorter:[11,5,1,""],componentSizeDistribution:[11,6,1,""],edgeComponentSizeDistribution:[11,6,1,""],edgeDegreeDistribution:[11,6,1,""],getEdgeComponentMappings:[11,6,1,""],getEdgeComponents:[11,8,1,""],getVertexComponentMappings:[11,6,1,""],getVertexComponents:[11,8,1,""],vertexComponentSizeDistribution:[11,6,1,""],vertexDegreeDistribution:[11,6,1,""]},PropertyMaps:{PropertyMap:[12,5,1,""],PropertyMapImpl:[12,3,1,""],UninitializedPropertyMap:[12,6,1,""]},TerminationDetection:{"<=>":[13,6,1,""],TerminationDetector:[13,5,1,""],TerminationDetectorImpl:[13,3,1,""]},Traversal:{edgeBFS:[14,8,1,""],vertexBFS:[14,8,1,""]},Utilities:{"_arrayEquality":[15,6,1,""],"_globalIntRandomStream":[15,4,1,""],"_globalRealRandomStream":[15,4,1,""],"_intersectionSizeAtLeast":[15,6,1,""],ArrayRef:[15,5,1,""],Centralized:[15,3,1,""],all:[15,6,1,""],any:[15,6,1,""],arrayEquality:[15,6,1,""],beginProfile:[15,6,1,""],chpl_comm_get_nb:[15,6,1,""],chpl_comm_nb_handle_t:[15,9,1,""],createBlock:[15,6,1,""],createCyclic:[15,6,1,""],debug:[15,6,1,""],endProfile:[15,6,1,""],forEachCorePerLocale:[15,8,1,""],forEachLocale:[15,8,1,""],getAddr:[15,6,1,""],getLines:[15,8,1,""],getLocale:[15,6,1,""],getLocaleID:[15,6,1,""],getNodeID:[15,6,1,""],get_nb:[15,6,1,""],intersection:[15,6,1,""],intersectionSize:[15,6,1,""],intersectionSizeAtLeast:[15,6,1,""],printDebugInformation:[15,4,1,""],profileCommDiagnostics:[15,4,1,""],profileCommDiagnosticsVerbose:[15,4,1,""],profileVisualDebug:[15,4,1,""],randInt:[15,6,1,""],randReal:[15,6,1,""]},Vectors:{Vector:[16,3,1,""],VectorGrowthRate:[16,4,1,""],VectorImpl:[16,3,1,""]},Visualize:{main:[17,6,1,""],visualize:[17,6,1,""]},WorkQueue:{"<=>":[18,6,1,""],Bag:[18,3,1,""],UninitializedWorkQueue:[18,6,1,""],WorkQueue:[18,5,1,""],WorkQueueImpl:[18,3,1,""],WorkQueueNoAggregation:[18,4,1,""],WorkQueueUnlimitedAggregation:[18,4,1,""],doWorkLoop:[18,8,1,""],main:[18,6,1,""],workQueueInitialBlockSize:[18,4,1,""],workQueueMaxBlockSize:[18,4,1,""],workQueueMaxTightSpinCount:[18,4,1,""],workQueueMinTightSpinCount:[18,4,1,""],workQueueMinVelocityForFlush:[18,4,1,""],workQueueVerbose:[18,4,1,""]}},objnames:{"0":["chpl","module"," module"],"1":["chpl","method"," method"],"2":["chpl","attribute"," attribute"],"3":["chpl","class"," class"],"4":["chpl","data"," data"],"5":["chpl","record"," record"],"6":["chpl","function"," function"],"7":["chpl","itermethod"," itermethod"],"8":["chpl","iterfunction"," iterfunction"],"9":["chpl","type"," type"]},objtypes:{"0":"chpl:module","1":"chpl:method","2":"chpl:attribute","3":"chpl:class","4":"chpl:data","5":"chpl:record","6":"chpl:function","7":"chpl:itermethod","8":"chpl:iterfunction","9":"chpl:type"},terms:{"_arrayequ":15,"_cast":1,"_dummi":16,"_edgesdomain":1,"_eproptyp":1,"_globalintrandomstream":15,"_globalrealrandomstream":15,"_intersectionsizeatleast":15,"_iteratorrecord":[15,16],"_not_":1,"_pid":10,"_round":9,"_v1":10,"_v2":10,"_valu":[2,7,10,12,13,14,15,18],"_verticesdomain":1,"_vproptyp":1,"abstract":8,"boolean":4,"case":18,"class":[1,2,7,8,10,12,13,15,16,18],"const":[2,3,6,9,15,16,18],"default":[1,9],"export":17,"int":[1,2,4,7,9,10,11,12,13,15,16,18],"new":[1,12,18],"null":1,"return":[1,2,4,11],"throw":[1,3,17],"true":[3,4,9,12],"var":[1,2,7,8,9,10,11,12,13,15,16,18],"void":7,"while":1,about:13,access:1,accumul:8,accumulateontost:8,ack:6,acquir:7,acquirelock:12,act:1,activ:1,add:[1,8,18],add_inclus:6,addedg:10,addinclus:1,addinclusionbuff:1,addr:15,addwork:18,adjac:1,adjlisthypergraph:0,adjlisthypergraphdisableaggreg:1,adjlisthypergraphdisableprivat:1,adjlisthypergraphimpl:[1,4],advis:1,after:[1,2,14,15],agg:7,aggreg:[1,2,7,12],aggregationbuff:0,aggregatorbuffers:2,aggregatordebug:2,aggregatorimpl:2,aggregatormaxbuff:2,aliv:13,all:[1,4,7,8,9,11,13,15],alloc:1,allow:1,along:1,alreadi:12,also:1,ani:[1,4,15],anoth:[1,8,13],apart:1,append:[7,12,16],approach:18,arbitrarili:8,areadjacentvertic:4,arg:[1,2,3,11,15],argument:[1,4,9,11,12,15],arr:[7,9,15,16],arrai:[1,4,11,15],arrayequ:15,arrayref:15,assign:11,associ:[1,4,8],assumpt:1,asynctask:18,atomicbool:[7,10,18],automat:1,avoid:7,awaittermin:13,back:2,background:7,bag:18,bagseg:18,balanc:18,base:8,becom:13,been:13,befor:13,begin:13,beginprofil:15,behavior:2,benefit:13,best:18,between:9,bidirect:1,binread:[0,1],bintograph:3,bintohypergraph:3,bipartit:1,block:[1,9],bool:[1,13,18],both:[1,11,13,14],boundingbox:1,boundscheck:1,breadth:14,buf:7,buffer:[1,2,7],butterfli:0,c_int:15,c_void_ptr:15,cachedneighborlist:10,cachedneighborlistdom:10,cachevalid:10,calcuat:4,calcul:4,calculatework:9,call:[1,7],can:[1,4,11,13,14,15],candid:[1,8],candidatesdom:8,cannot:1,cap:[2,16],captur:15,cardin:1,care:15,cast:4,caus:1,ceas:1,central:15,certain:1,chanc:18,chang:1,chapel:[0,13,15],check:[1,4,15],chgl:0,child:13,chosen:8,chpl__processoratomictyp:[13,18],chpl__tuple_arg_temp:1,chpl_comm_get_nb:15,chpl_comm_nb_handle_t:15,chpl_localeid_t:15,chpl_nodeid_t:15,chunksiz:15,clear:16,clone:[8,12],cmp:8,cmptype:8,code:14,coeffici:4,coforal:1,collaps:1,collapseedg:1,collapsesubset:1,collapsevertic:1,combin:[4,8],come:7,commid:15,common:[4,11],commun:1,compar:4,compil:[1,11],compon:[1,11,14],componentmap:11,componentsizedistribut:11,comput:[8,9],computeaffinityblock:9,config:[1,2,3,6,9,15,16,18],connect:11,contain:[1,2,4],content:0,contract:1,copi:[1,2,12,15],count:[4,11],counter:13,couponcollector:9,creat:[1,7,9,12,13,15],create_graph:6,createblock:15,createcycl:15,csc:1,csr:1,current:[1,2,8,12],cut:1,cycl:4,cyclic:1,cylc:4,data:[2,7,13],dataset:3,debug:[2,3,15],debug_bin_read:3,decrement:13,deep:12,defaultdist:1,defaultmapp:12,defaultrectangulardist:1,defin:4,degre:[1,4,9,10,11],deinit:[2,7,18],delet:1,delimitor:1,depth:14,dequeu:18,desc:1,descriptor:1,desir:[1,4,9],desired_edge_degre:9,desired_vertex_degre:9,desirededgedegre:9,desiredvertexdegre:9,destbuff:18,destroi:[1,2,7,10,12,13,18],detect:[13,14],detector:13,determin:[1,8,12,13,15],disabl:1,distributedhistogram:9,doe:12,dom:[7,9,15,16],domain:[1,8,11,15],done:[2,7,14],dosomethingto:13,dot:17,doworkloop:18,dsigetprivatizedata:[2,7,13,18],dsiprivat:[2,7,13,18],duplic:[1,4,8,12],dure:1,dynam:7,dynamicaggreg:7,dynamicaggregationbuff:0,dynamicaggregatorimpl:7,dynamicarrai:9,dynamicbuff:7,dynamicdestbuff:[7,18],each:[1,4,8,13,18],easi:[8,13],eddom:9,edegseq:9,edegseqdom:9,edesc:1,edesctyp:[1,4,14],edg:[1,4,9,11],edgebf:14,edgecomponentsizedistribut:11,edgecount:10,edgedegreedistribut:11,edgedomain:9,edgemap:1,edgescan:9,edgesdomain:[1,9],edgesmap:[1,10],edgesort:11,edgeswithdegre:4,edgewrappereindextyp:1,eduplicatehistogram:1,effect:15,effici:8,effort:18,eindextyp:1,element:[1,8,18],els:10,elt:[16,18],elttyp:[16,18],emc:9,emcdom:9,empti:12,enabl:[1,15],endprofil:15,enough:13,enqueu:18,entir:[9,15],epropmap:1,eproptyp:1,eqclass:8,eqclassesdom:8,equival:[1,8,13],equivalenceclass:0,erdo:9,evalu:15,even:13,evenli:18,everi:[1,4],everyth:10,exampl:[1,8,13],except:15,exist:[1,4,8,12],expand:2,experi:2,explicit:[1,7],explicitli:[1,7],fals:[1,2,3,4,12,15,18],fast:1,fetch:4,few:1,file:[1,15],filenam:[1,17],find:18,finish:13,first:[4,14],flush:[1,7,10,18],flushbuff:1,flushglob:[2,7,12],flushloc:[2,7,12,18],followthi:[1,2],foral:[1,10],foreachcoreperlocal:15,foreachlocal:15,format:17,forward:[1,10],found:12,from:[1,9],fromadjacencylist:1,full:14,furthermor:18,futur:15,gener:[0,1,8],generatebt:9,generatechunglu:9,generatechungluadjust:9,generatechungluprescansmp:9,generatechunglusmp:9,generateerdosrenyi:9,generateerdosrenyismp:9,generationseedoffset:9,generationuseaggreg:9,get:7,get_hostnam:6,get_nb:15,get_siz:6,getaddr:15,getadjacentvertic:4,getarrai:[2,7,16],getcandid:8,getdomain:2,getedg:[1,10],getedgebutterfli:4,getedgecaterpillar:4,getedgecompon:11,getedgecomponentmap:11,getedgedegre:1,getedgemetamorphcoef:4,getedgeperdegreemetamorphosiscoeffici:4,getequivalenceclass:8,getinclus:1,getinclusionmetamorphcoef:4,getinclusionnumbutterfli:4,getinclusionnumcaterpillar:4,getlin:15,getlocal:[1,15],getlocaleid:15,getnodeid:15,getprivatizedinst:[2,7,13,18],getproperti:[1,12],getptr:2,getstatist:13,gettoplex:1,getvertexbutterfli:4,getvertexcaterpillar:4,getvertexcompon:11,getvertexcomponentmap:11,getvertexdegre:1,getvertexmetamorphcoef:4,getvertexperdegreemetamorphosiscoeffici:4,getvertic:1,getwork:18,given:[1,4,13],globals:18,goe:15,graph:[0,1,9],graphimpl:10,graphviz:17,group:11,growthrat:16,half:1,handl:7,hasedg:10,hash:12,hasinclus:1,hastermin:13,have:[1,4,7,13,14,18],help:18,henc:[1,13,15],here:18,high:15,higher:13,highest:4,histogram:[1,9,11],hold:7,hyperedg:[1,8,9,11],ideal:18,ident:8,identifi:1,idtyp:1,idx:[2,9,15,16],implement:[10,13,14],implicit:[1,15],incid:[1,8],includ:[4,9,15],inclus:4,inclusionstoadd:9,increas:[13,18],increment:13,index:[0,1,2,4],init:[1,2,7,8,9,10,11,12,13,15,16,18],initi:12,inplac:1,input:4,insertaggreg:10,instanc:[1,2,7,10,13,15,18],instead:1,integ:[1,4],integr:[1,2,4,9,10,15,16],intent:13,intern:12,intersect:[1,10,11,15,16],intersections:[1,10,15,16],intersectionsizeatleast:15,invalidatecach:10,invok:[1,2],involv:13,iscachevalid:10,isconnect:1,isempti:18,isimmut:1,isiniti:[2,7,12,18],isol:1,isshutdown:18,issu:7,item:9,iter:[1,2,4,7,8,10,11,12,14,15,16,18],iterkind:[1,2,4,7,8,10,12,15,16,18],itself:[1,15],just:13,keep:8,kei:[8,11,12],keytyp:8,keytypeequival:8,keytypeequivalencecmptyp:8,known:8,larg:1,leader:8,least:[1,4,11,15],left:13,less:18,level:9,lifetim:15,like:18,link:14,list:[1,4,14],loc:[2,7,18],local:[1,2,7,9,12,13,15,18],localespac:7,localproperti:12,locat:13,locid:[2,7,18],lock:[7,12],loop:1,low:15,lower:13,magnitud:14,main:[3,6,8,17,18],maintain:1,make:[7,8,13],makerandomstream:15,map:[1,10,11,12],mapper:12,mappertyp:12,matrix:1,maxbackoff:13,maximum:4,maxparallelsegmentspac:18,maxtaskpar:18,memori:1,metamorphosi:4,method:[2,15],metric:0,minbackoff:13,minimum:11,modifi:1,modul:0,mostli:15,msg:[2,7],msgtype:[2,7],multbackoff:13,multipl:[1,13],must:[1,2,9,13,15],mutabl:9,naiv:1,name:1,narg:[2,3],need:[7,14],neighbor:[1,4,10],neighborlist:4,never:7,nextstartidxdeq:18,nextstartidxenq:18,node:[13,15],nodedata:1,nodetyp:1,nodetypewrapp:1,nodetypewrapperidtyp:1,nop:1,nor:12,normal:1,note:[1,14,15],now:1,num_edg:9,num_vertic:9,numaggregatedwork:18,number:[1,4,9,11],numedg:[1,10],numedgespres:3,numer:4,numinclus:9,numoper:9,numproperti:12,numpropertiesglob:12,numrandom:9,numvertic:[1,10],object:[1,4],obtain:[1,11,12,15],occur:[13,15],offer:14,onc:13,onli:15,open:7,oper:1,optim:[1,15],order:14,origin:[1,12,15],other:[1,2,7,8,9,10,12,13,16,18],our:18,out:[15,17],over:[2,9,11],overhead:1,overlap:18,overrid:16,overwrit:12,own:[7,13],page:0,pair:1,param:[1,2,3,4,6,7,8,9,10,12,15,16,18],parent:13,partial:7,particip:1,pass:1,pattern:14,per:4,perform:[1,9,11,12,13],pid:[2,7,10,13,15,18],placement:18,point:1,polici:12,pool:2,possibl:[4,7],print:15,printdebuginform:15,privat:[1,12,13,15],privatizedcachedneighborlistinst:10,privatizedcachedneighborlistpid:10,probabl:9,probtabl:9,proc:[1,2,3,4,6,7,8,9,10,11,12,13,15,16,17,18],profilecommdiagnost:15,profilecommdiagnosticsverbos:15,profilevisualdebug:15,progress:[1,7],properti:[1,12],propertymap:[0,1],propertymapimpl:12,propertytyp:12,propertytypepropertymap:12,prototyp:10,provid:[1,8],pure:1,queri:4,queue:18,raddr:15,randint:15,randreal:15,randvalu:9,rang:[4,15],rather:1,read:1,reader:1,readwritethi:[1,2,8,16],real:[4,9,15,16],record:[1,2,7,9,10,11,12,13,15,18],recycl:2,reduc:13,reduceeqclass:8,reducescanop:8,reduct:[8,13],ref:[1,2,8,9,13,15,16,18],refer:[1,12,15],regard:1,releas:7,remot:[2,13,15],remov:[1,18],removedupl:1,removeisolatedcompon:1,renyi:9,repres:[1,4],request:7,requir:14,respect:[1,13],result:[1,12],right:13,rng:15,rngoffset:9,rngseed:9,robin:18,round:18,safe:1,same:[1,11,12,13],scope:15,search:[0,14],second:4,segment:18,select:8,self:2,send:7,sent:7,separ:1,sequenc:[1,9],sequenti:1,serial:12,serv:1,server:0,serverport:6,set:[1,8,9,12],setproperti:12,sever:1,shallow:[1,12],share:[1,4],should:[1,10],shutdown:18,shutdownsign:18,side:15,significantli:11,similar:1,simpl:10,simplifi:[1,10],sink:1,size:[1,2,7,11,15,16,18],size_t:15,slower:11,sort:[9,16],sourc:1,spawn:13,speedup:14,start:13,startaggreg:1,startidx:[1,15],startidxdeq:18,startidxenq:18,state:8,statement:1,still:[1,15],stopaggreg:1,storag:1,store:[1,4],strictli:1,string:[1,3,6,15],subject:2,subset:[1,9],sum:1,superset:1,support:10,syn:6,tag:[1,2,4,7,8,10,12,15,16,18],target:4,targetloc:9,targetlocal:[2,9],task:[7,13],tasksfinish:13,tasksstart:13,term:[1,13],termin:[13,14],terminationdetect:0,terminationdetector:[13,18],terminationdetectorimpl:13,test:4,than:[1,11,13],thei:[1,18],them:[1,11],thi:[1,2,4,7,8,9,11,12,14,15,16],thread:1,through:1,time:[1,13],todo:2,toedg:1,toplex:1,tovertex:1,travers:0,treat:15,truth:4,twice:13,two:[1,4,9,13,15],type:[1,2,4,7,8,10,12,15,16,18],typeindex:15,uint:18,unaffect:15,undefin:2,under:4,underli:10,uniform:10,uniniti:12,uninitializedaggreg:[2,7,10,18],uninitializeddynamicaggreg:[7,18],uninitializedpropertymap:12,uninitializedworkqueu:18,unmanag:[1,2,7,8,10,13,18],unrol:14,until:7,updat:[1,13],user:[1,2,7,15],util:0,valid:1,validatecach:10,valu:[4,8,12,15],vddom:9,vdebug:15,vdebugnam:15,vdegseq:9,vdegseqdom:9,vdesc:1,vdesctyp:[1,4,10,14],vduplicatehistogram:1,vector:[0,10],vectorgrowthr:16,vectorimpl:16,veri:13,verifi:1,version:1,vertex:[1,4,9,11],vertexbf:14,vertexcomponentsizedistribut:11,vertexdegreedistribut:11,vertexdomain:9,vertexhasneighbor:4,vertexmap:1,vertexscan:9,vertexsort:11,vertexwrappervindextyp:1,vertic:[1,4,8,9,11],verticesdomain:[1,9,10],verticesmap:[1,10],verticeswithdegre:4,via:1,vindextyp:1,visit:13,visitor:14,visual:0,vmc:9,vmcdom:9,vpropmap:1,vproptyp:1,wai:1,walk:[1,11],warn:15,weightedrandomsampl:9,what:8,when:[7,12],where:[1,4,8,18],whether:[1,12,13,15],which:[1,8,9,12,13,15],within:[1,4],without:[1,4,15],work:[1,18],workinfo:9,workpend:18,workqueu:0,workqueueimpl:18,workqueueinitialblocks:18,workqueuemaxblocks:18,workqueuemaxtightspincount:18,workqueuemintightspincount:18,workqueueminvelocityforflush:18,workqueuenoaggreg:18,workqueueunlimitedaggreg:18,workqueueverbos:18,worktyp:18,would:1,wq1:18,wq2:18,wrapper:[1,15],yield:[1,4],you:1},titles:["chpldoc documentation","AdjListHyperGraph","AggregationBuffer","BinReader","Butterfly","CHGL","CHGL-Server","DynamicAggregationBuffer","EquivalenceClasses","Generation","Graph","Metrics","PropertyMaps","TerminationDetection","Traversal","Utilities","Vectors","Visualize","WorkQueue"],titleterms:{adjlisthypergraph:1,aggregationbuff:2,binread:3,butterfli:4,chgl:[5,6],chpldoc:0,distribut:1,document:0,dual:1,dynamicaggregationbuff:7,equivalenceclass:8,gener:9,global:1,graph:10,hypergraph:1,indic:0,metric:11,parallel:1,propertymap:12,server:6,tabl:0,terminationdetect:13,travers:14,usag:1,util:15,vector:16,view:1,visual:17,workqueu:18}})