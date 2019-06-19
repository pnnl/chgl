Search.setIndex({envversion:46,filenames:["index","modules/src/AdjListHyperGraph","modules/src/AggregationBuffer","modules/src/BinReader","modules/src/Butterfly","modules/src/CHGL","modules/src/DynamicAggregationBuffer","modules/src/EquivalenceClasses","modules/src/Generation","modules/src/Graph","modules/src/Metrics","modules/src/PropertyMaps","modules/src/TerminationDetection","modules/src/Traversal","modules/src/Utilities","modules/src/Vectors","modules/src/Visualize","modules/src/WorkQueue"],objects:{"":{AdjListHyperGraph:[1,0,0,"-"],AggregationBuffer:[2,0,0,"-"],BinReader:[3,0,0,"-"],Butterfly:[4,0,0,"-"],CHGL:[5,0,0,"-"],DynamicAggregationBuffer:[6,0,0,"-"],EquivalenceClasses:[7,0,0,"-"],Generation:[8,0,0,"-"],Graph:[9,0,0,"-"],Metrics:[10,0,0,"-"],PropertyMaps:[11,0,0,"-"],TerminationDetection:[12,0,0,"-"],Traversal:[13,0,0,"-"],Utilities:[14,0,0,"-"],Vectors:[15,0,0,"-"],Visualize:[16,0,0,"-"],WorkQueue:[17,0,0,"-"]},"AdjListHyperGraph.AdjListHyperGraph":{destroy:[1,1,1,""],init:[1,1,1,""]},"AdjListHyperGraph.AdjListHyperGraphImpl":{"this":[1,1,1,""],addInclusion:[1,1,1,""],addInclusionBuffered:[1,1,1,""],collapse:[1,1,1,""],collapseEdges:[1,1,1,""],collapseSubsets:[1,1,1,""],collapseVertices:[1,1,1,""],degree:[1,1,1,""],eDescType:[1,2,1,""],eIndexType:[1,2,1,""],edgesDomain:[1,1,1,""],flushBuffers:[1,1,1,""],getEdgeDegrees:[1,1,1,""],getEdges:[1,1,1,""],getInclusions:[1,1,1,""],getLocale:[1,1,1,""],getProperty:[1,1,1,""],getToplexes:[1,6,1,""],getVertexDegrees:[1,1,1,""],getVertices:[1,6,1,""],hasInclusion:[1,1,1,""],incidence:[1,6,1,""],intersection:[1,6,1,""],intersectionSize:[1,1,1,""],isConnected:[1,1,1,""],numEdges:[1,1,1,""],numVertices:[1,1,1,""],removeDuplicates:[1,1,1,""],removeIsolatedComponents:[1,1,1,""],startAggregation:[1,1,1,""],stopAggregation:[1,1,1,""],these:[1,6,1,""],toEdge:[1,1,1,""],toVertex:[1,1,1,""],vDescType:[1,2,1,""],vIndexType:[1,2,1,""],verticesDomain:[1,1,1,""],walk:[1,6,1,""]},"AdjListHyperGraph.Wrapper":{"null":[1,1,1,""],id:[1,2,1,""],idType:[1,2,1,""],nodeType:[1,2,1,""],readWriteThis:[1,1,1,""]},"AggregationBuffer.Aggregator":{"_value":[2,1,1,""],destroy:[2,1,1,""],init:[2,1,1,""],instance:[2,2,1,""],isInitialized:[2,1,1,""],msgType:[2,2,1,""],pid:[2,2,1,""]},"AggregationBuffer.AggregatorImpl":{aggregate:[2,1,1,""],deinit:[2,1,1,""],dsiGetPrivatizeData:[2,1,1,""],dsiPrivatize:[2,1,1,""],flushGlobal:[2,6,1,""],flushLocal:[2,6,1,""],getPrivatizedInstance:[2,1,1,""],init:[2,1,1,""],msgType:[2,2,1,""]},"AggregationBuffer.Buffer":{"this":[2,1,1,""],cap:[2,1,1,""],done:[2,1,1,""],getArray:[2,1,1,""],getDomain:[2,1,1,""],getPtr:[2,1,1,""],msgType:[2,2,1,""],readWriteThis:[2,1,1,""],size:[2,1,1,""],these:[2,6,1,""]},"Butterfly.AdjListHyperGraphImpl":{areAdjacentVertices:[4,1,1,""],edgesWithDegree:[4,6,1,""],getAdjacentVertices:[4,6,1,""],getEdgeButterflies:[4,1,1,""],getEdgeCaterpillars:[4,1,1,""],getEdgeMetamorphCoefs:[4,1,1,""],getEdgePerDegreeMetamorphosisCoefficients:[4,1,1,""],getInclusionMetamorphCoef:[4,1,1,""],getInclusionNumButterflies:[4,1,1,""],getInclusionNumCaterpillars:[4,1,1,""],getVertexButterflies:[4,1,1,""],getVertexCaterpillars:[4,1,1,""],getVertexMetamorphCoefs:[4,1,1,""],getVertexPerDegreeMetamorphosisCoefficients:[4,1,1,""],vertexHasNeighbor:[4,1,1,""],verticesWithDegree:[4,6,1,""]},"DynamicAggregationBuffer.DynamicAggregator":{"_value":[6,1,1,""],destroy:[6,1,1,""],init:[6,1,1,""],instance:[6,2,1,""],isInitialized:[6,1,1,""],msgType:[6,2,1,""],pid:[6,2,1,""]},"DynamicAggregationBuffer.DynamicAggregatorImpl":{agg:[6,2,1,""],aggregate:[6,1,1,""],dsiGetPrivatizeData:[6,1,1,""],dsiPrivatize:[6,1,1,""],dynamicDestBuffers:[6,2,1,""],flushGlobal:[6,6,1,""],flushLocal:[6,6,1,""],getPrivatizedInstance:[6,1,1,""],init:[6,1,1,""],msgType:[6,2,1,""],pid:[6,2,1,""]},"DynamicAggregationBuffer.DynamicBuffer":{acquire:[6,1,1,""],append:[6,1,1,""],arr:[6,2,1,""],dom:[6,2,1,""],done:[6,1,1,""],getArray:[6,1,1,""],lock:[6,2,1,""],msgType:[6,2,1,""],release:[6,1,1,""],size:[6,1,1,""]},"EquivalenceClasses.Equivalence":{add:[7,1,1,""],candidates:[7,2,1,""],candidatesDom:[7,2,1,""],cmpType:[7,2,1,""],eqclasses:[7,2,1,""],eqclassesDom:[7,2,1,""],getCandidates:[7,6,1,""],getEquivalenceClasses:[7,6,1,""],init:[7,1,1,""],keyType:[7,2,1,""],readWriteThis:[7,1,1,""],reduction:[7,1,1,""]},"EquivalenceClasses.ReduceEQClass":{accumulate:[7,1,1,""],accumulateOntoState:[7,1,1,""],clone:[7,1,1,""],cmpType:[7,2,1,""],combine:[7,1,1,""],generate:[7,1,1,""],identity:[7,1,1,""],init:[7,1,1,""],keyType:[7,2,1,""],value:[7,2,1,""]},"Generation.DynamicArray":{"this":[8,1,1,""],arr:[8,2,1,""],dom:[8,2,1,""],init:[8,1,1,""]},"Generation.WorkInfo":{numOperations:[8,2,1,""],rngOffset:[8,2,1,""],rngSeed:[8,2,1,""]},"Graph.Graph":{"_value":[9,1,1,""],destroy:[9,1,1,""],init:[9,1,1,""],instance:[9,2,1,""],pid:[9,2,1,""]},"Graph.GraphImpl":{addEdge:[9,1,1,""],cacheValid:[9,2,1,""],cachedNeighborList:[9,2,1,""],cachedNeighborListDom:[9,2,1,""],degree:[9,1,1,""],edgeCounter:[9,2,1,""],flush:[9,1,1,""],getEdges:[9,6,1,""],hasEdge:[9,1,1,""],hg:[9,2,1,""],init:[9,1,1,""],insertAggregator:[9,2,1,""],intersection:[9,1,1,""],intersectionSize:[9,1,1,""],invalidateCache:[9,1,1,""],isCacheValid:[9,1,1,""],neighbors:[9,6,1,""],pid:[9,2,1,""],privatizedCachedNeighborListInstance:[9,2,1,""],privatizedCachedNeighborListPID:[9,2,1,""],simplify:[9,1,1,""],vDescType:[9,2,1,""],validateCache:[9,1,1,""]},"PropertyMaps.PropertyMap":{"_value":[11,1,1,""],clone:[11,1,1,""],destroy:[11,1,1,""],init:[11,1,1,""],isInitialized:[11,1,1,""],mapperType:[11,2,1,""],propertyType:[11,2,1,""]},"PropertyMaps.PropertyMapImpl":{append:[11,1,1,""],create:[11,1,1,""],flushGlobal:[11,1,1,""],flushLocal:[11,1,1,""],getProperty:[11,1,1,""],init:[11,1,1,""],localProperties:[11,6,1,""],lock:[11,2,1,""],mapper:[11,2,1,""],numProperties:[11,1,1,""],numPropertiesGlobal:[11,1,1,""],propertyType:[11,2,1,""],setProperty:[11,1,1,""],these:[11,6,1,""]},"TerminationDetection.TerminationDetector":{"_value":[12,1,1,""],init:[12,1,1,""],instance:[12,2,1,""],pid:[12,2,1,""]},"TerminationDetection.TerminationDetectorImpl":{awaitTermination:[12,1,1,""],dsiGetPrivatizeData:[12,1,1,""],dsiPrivatize:[12,1,1,""],finished:[12,1,1,""],getPrivatizedInstance:[12,1,1,""],getStatistics:[12,1,1,""],hasTerminated:[12,1,1,""],init:[12,1,1,""],pid:[12,2,1,""],started:[12,1,1,""],tasksFinished:[12,2,1,""],tasksStarted:[12,2,1,""]},"Utilities.ArrayRef":{"_value":[14,1,1,""],init:[14,1,1,""],instance:[14,2,1,""],pid:[14,2,1,""]},"Utilities.Centralized":{init:[14,1,1,""],x:[14,2,1,""]},"Vectors.Vector":{"_dummy":[15,2,1,""],"this":[15,1,1,""],append:[15,1,1,""],clear:[15,1,1,""],eltType:[15,2,1,""],getArray:[15,1,1,""],init:[15,1,1,""],intersection:[15,1,1,""],intersectionSize:[15,1,1,""],size:[15,1,1,""],sort:[15,1,1,""],these:[15,6,1,""]},"Vectors.VectorImpl":{"this":[15,1,1,""],append:[15,1,1,""],arr:[15,2,1,""],cap:[15,2,1,""],clear:[15,1,1,""],dom:[15,2,1,""],getArray:[15,1,1,""],growthRate:[15,2,1,""],init:[15,1,1,""],intersection:[15,1,1,""],intersectionSize:[15,1,1,""],readWriteThis:[15,1,1,""],size:[15,1,1,""],sort:[15,1,1,""],sz:[15,2,1,""],these:[15,6,1,""]},"WorkQueue.Bag":{add:[17,1,1,""],deinit:[17,1,1,""],eltType:[17,2,1,""],init:[17,1,1,""],maxParallelSegmentSpace:[17,2,1,""],nextStartIdxDeq:[17,1,1,""],nextStartIdxEnq:[17,1,1,""],remove:[17,1,1,""],segments:[17,2,1,""],size:[17,1,1,""],startIdxDeq:[17,2,1,""],startIdxEnq:[17,2,1,""]},"WorkQueue.WorkQueue":{"_value":[17,1,1,""],init:[17,1,1,""],instance:[17,2,1,""],isInitialized:[17,1,1,""],pid:[17,2,1,""],workType:[17,2,1,""]},"WorkQueue.WorkQueueImpl":{addWork:[17,1,1,""],asyncTasks:[17,2,1,""],destBuffer:[17,2,1,""],dsiGetPrivatizeData:[17,1,1,""],dsiPrivatize:[17,1,1,""],dynamicDestBuffer:[17,2,1,""],flush:[17,1,1,""],flushLocal:[17,1,1,""],getPrivatizedInstance:[17,1,1,""],getWork:[17,1,1,""],globalSize:[17,1,1,""],init:[17,1,1,""],isEmpty:[17,1,1,""],isShutdown:[17,1,1,""],pid:[17,2,1,""],queue:[17,2,1,""],shutdown:[17,1,1,""],shutdownSignal:[17,2,1,""],size:[17,1,1,""],workType:[17,2,1,""]},AdjListHyperGraph:{"!=":[1,5,1,""],"+=":[1,5,1,""],"<":[1,5,1,""],"==":[1,5,1,""],">":[1,5,1,""],"_cast":[1,5,1,""],AdjListHyperGraph:[1,4,1,""],AdjListHyperGraphDisableAggregation:[1,7,1,""],AdjListHyperGraphDisablePrivatization:[1,7,1,""],AdjListHyperGraphImpl:[1,3,1,""],Wrapper:[1,4,1,""],fromAdjacencyList:[1,5,1,""],id:[1,5,1,""]},AggregationBuffer:{Aggregator:[2,4,1,""],AggregatorBufferSize:[2,7,1,""],AggregatorDebug:[2,7,1,""],AggregatorImpl:[2,3,1,""],AggregatorMaxBuffers:[2,7,1,""],Buffer:[2,3,1,""],UninitializedAggregator:[2,5,1,""],debug:[2,5,1,""]},BinReader:{DEBUG_BIN_READER:[3,7,1,""],binToGraph:[3,5,1,""],binToHypergraph:[3,5,1,""],debug:[3,5,1,""],main:[3,5,1,""]},Butterfly:{combinations:[4,5,1,""]},DynamicAggregationBuffer:{DynamicAggregator:[6,4,1,""],DynamicAggregatorImpl:[6,3,1,""],DynamicBuffer:[6,3,1,""],UninitializedDynamicAggregator:[6,5,1,""]},EquivalenceClasses:{Equivalence:[7,3,1,""],ReduceEQClass:[7,3,1,""],main:[7,5,1,""]},Generation:{"_round":[8,5,1,""],DynamicArray:[8,4,1,""],GenerationSeedOffset:[8,7,1,""],GenerationUseAggregation:[8,7,1,""],WorkInfo:[8,4,1,""],calculateWork:[8,5,1,""],computeAffinityBlocks:[8,5,1,""],distributedHistogram:[8,5,1,""],generateBTER:[8,5,1,""],generateChungLu:[8,5,1,""],generateChungLuAdjusted:[8,5,1,""],generateChungLuPreScanSMP:[8,5,1,""],generateChungLuSMP:[8,5,1,""],generateErdosRenyi:[8,5,1,""],generateErdosRenyiSMP:[8,5,1,""],histogram:[8,5,1,""],weightedRandomSample:[8,5,1,""]},Graph:{Graph:[9,4,1,""],GraphImpl:[9,3,1,""]},Metrics:{edgeComponentSizeDistribution:[10,5,1,""],edgeDegreeDistribution:[10,5,1,""],getEdgeComponentMappings:[10,5,1,""],getEdgeComponents:[10,8,1,""],getVertexComponents:[10,8,1,""],vertexComponentSizeDistribution:[10,5,1,""],vertexDegreeDistribution:[10,5,1,""]},PropertyMaps:{PropertyMap:[11,4,1,""],PropertyMapImpl:[11,3,1,""],UninitializedPropertyMap:[11,5,1,""]},TerminationDetection:{"<=>":[12,5,1,""],TerminationDetector:[12,4,1,""],TerminationDetectorImpl:[12,3,1,""]},Traversal:{edgeBFS:[13,8,1,""],vertexBFS:[13,8,1,""]},Utilities:{"_arrayEquality":[14,5,1,""],"_globalIntRandomStream":[14,7,1,""],"_globalRealRandomStream":[14,7,1,""],"_intersectionSizeAtLeast":[14,5,1,""],ArrayRef:[14,4,1,""],Centralized:[14,3,1,""],all:[14,5,1,""],any:[14,5,1,""],arrayEquality:[14,5,1,""],beginProfile:[14,5,1,""],chpl_comm_get_nb:[14,5,1,""],chpl_comm_nb_handle_t:[14,9,1,""],createBlock:[14,5,1,""],createCyclic:[14,5,1,""],debug:[14,5,1,""],endProfile:[14,5,1,""],getAddr:[14,5,1,""],getLines:[14,8,1,""],getLocale:[14,5,1,""],getLocaleID:[14,5,1,""],getNodeID:[14,5,1,""],get_nb:[14,5,1,""],intersection:[14,5,1,""],intersectionSize:[14,5,1,""],intersectionSizeAtLeast:[14,5,1,""],printDebugInformation:[14,7,1,""],profileCommDiagnostics:[14,7,1,""],profileCommDiagnosticsVerbose:[14,7,1,""],profileVisualDebug:[14,7,1,""],randInt:[14,5,1,""],randReal:[14,5,1,""]},Vectors:{Vector:[15,3,1,""],VectorGrowthRate:[15,7,1,""],VectorImpl:[15,3,1,""]},Visualize:{main:[16,5,1,""],visualize:[16,5,1,""]},WorkQueue:{"<=>":[17,5,1,""],Bag:[17,3,1,""],UninitializedWorkQueue:[17,5,1,""],WorkQueue:[17,4,1,""],WorkQueueImpl:[17,3,1,""],WorkQueueNoAggregation:[17,7,1,""],WorkQueueUnlimitedAggregation:[17,7,1,""],doWorkLoop:[17,8,1,""],main:[17,5,1,""],workQueueInitialBlockSize:[17,7,1,""],workQueueMaxBlockSize:[17,7,1,""],workQueueMaxTightSpinCount:[17,7,1,""],workQueueMinTightSpinCount:[17,7,1,""],workQueueMinVelocityForFlush:[17,7,1,""]}},objnames:{"0":["chpl","module"," module"],"1":["chpl","method"," method"],"2":["chpl","attribute"," attribute"],"3":["chpl","class"," class"],"4":["chpl","record"," record"],"5":["chpl","function"," function"],"6":["chpl","itermethod"," itermethod"],"7":["chpl","data"," data"],"8":["chpl","iterfunction"," iterfunction"],"9":["chpl","type"," type"]},objtypes:{"0":"chpl:module","1":"chpl:method","2":"chpl:attribute","3":"chpl:class","4":"chpl:record","5":"chpl:function","6":"chpl:itermethod","7":"chpl:data","8":"chpl:iterfunction","9":"chpl:type"},terms:{"_arrayequ":14,"_cast":1,"_dummi":15,"_edgesdomain":1,"_eproptyp":1,"_globalintrandomstream":14,"_globalrealrandomstream":14,"_intersectionsizeatleast":14,"_iteratorrecord":[14,15],"_not_":1,"_pid":9,"_round":8,"_v1":9,"_v2":9,"_valu":[2,6,9,11,12,13,14,17],"_verticesdomain":1,"_vproptyp":1,"boolean":4,"case":17,"class":[1,2,6,7,9,11,12,14,15,17],"const":[2,8,14,15,17],"default":[1,8],"export":16,"int":[1,2,4,6,8,9,11,12,14,15,17],"new":[1,11,17],"null":1,"return":[1,2,4,10],"throw":[1,3,16],"true":[4,8,11],"var":[1,2,6,7,8,9,11,12,14,15,17],"void":6,"while":1,about:12,access:1,accumul:7,accumulateontost:7,acquir:6,acquirelock:11,act:1,activ:1,add:[1,7,17],addedg:9,addinclus:1,addinclusionbuff:1,addr:14,addwork:17,adjac:1,adjlisthypergraph:0,adjlisthypergraphdisableaggreg:1,adjlisthypergraphdisableprivat:1,adjlisthypergraphimpl:[1,4],advis:1,after:[1,2,13,14],agg:6,aggreg:[1,2,6,11],aggregationbuff:0,aggregatorbuffers:2,aggregatordebug:2,aggregatorimpl:2,aggregatormaxbuff:2,aliv:12,all:[1,4,6,8,10,12,14],alloc:1,allow:1,along:1,alreadi:11,also:1,ani:[1,4,14],anoth:[1,12],apart:1,append:[6,11,15],approach:17,areadjacentvertic:4,arg:[1,2,3,14],argument:[1,4,8,10,11,14],arr:[6,8,14,15],arrai:[1,4,10,14],arrayequ:14,arrayref:14,assign:10,associ:[1,4],assumpt:1,asynctask:17,atomicbool:[6,9,17],atomicint:12,automat:1,avoid:6,awaittermin:12,back:2,background:6,bag:17,bagseg:17,balanc:17,becom:12,been:12,befor:12,begin:12,beginprofil:14,behavior:2,benefit:12,best:17,between:8,bidirect:1,binread:[0,1],bintograph:3,bintohypergraph:3,bipartit:1,block:[1,8],bool:[1,12,17],both:[1,10,12,13],boundingbox:1,boundscheck:1,breadth:13,buf:6,buffer:[1,2,6],butterfli:0,c_int:14,c_void_ptr:14,cachedneighborlist:9,cachedneighborlistdom:9,cachevalid:9,calcuat:4,calcul:4,calculatework:8,call:[1,6],can:[1,4,10,12,13,14],candid:[1,7],candidatesdom:7,cannot:1,cap:[2,15],captur:14,cardin:1,care:14,cast:4,caus:1,ceas:1,central:14,certain:1,chanc:17,chapel:[0,12,14],check:[1,4,14],chgl:0,child:12,chpl__processoratomictyp:17,chpl__tuple_arg_temp:1,chpl_comm_get_nb:14,chpl_comm_nb_handle_t:14,chpl_localeid_t:14,chpl_nodeid_t:14,chunksiz:14,clear:15,clone:[7,11],cmptype:7,code:13,coeffici:4,coforal:1,collaps:1,collapseedg:1,collapsesubset:1,collapsevertic:1,combin:[4,7],come:6,commid:14,common:[4,10],commun:1,compar:4,compil:[1,10],compon:[1,10,13],comput:8,computeaffinityblock:8,config:[1,2,3,8,14,15,17],connect:10,contain:[1,2,4],content:0,copi:[1,2,11,14],count:[4,10],counter:12,couponcollector:8,creat:[1,6,8,11,12,14],createblock:14,createcycl:14,csc:1,csr:1,current:[1,2,11],cut:1,cycl:4,cyclic:1,cylc:4,data:[2,6,12],dataset:3,debug:[2,3,14],debug_bin_read:3,decrement:12,deep:11,defaultdist:1,defaultmapp:11,defaultrectangulardist:1,defin:4,degre:[1,4,8,9,10],deinit:[2,17],delet:1,delimitor:1,depth:13,dequeu:17,desc:1,descriptor:1,desir:[1,4,8],desired_edge_degre:8,desired_vertex_degre:8,desirededgedegre:8,desiredvertexdegre:8,destbuff:17,destroi:[1,2,6,9,11,12],detect:[12,13],detector:12,determin:[1,11,12,14],disabl:1,distributedhistogram:8,doe:11,dom:[6,8,14,15],domain:[1,7,10,14],done:[2,6,13],dosomethingto:12,dot:16,doworkloop:17,dsigetprivatizedata:[2,6,12,17],dsiprivat:[2,6,12,17],duplic:[1,4,11],dynam:6,dynamicaggreg:6,dynamicaggregationbuff:0,dynamicaggregatorimpl:6,dynamicarrai:8,dynamicbuff:6,dynamicdestbuff:[6,17],each:[1,4,12,17],easi:12,eddom:8,edegseq:8,edegseqdom:8,edesc:1,edesctyp:[1,4,13],edg:[1,4,8,10],edgebf:13,edgecomponentsizedistribut:10,edgecount:9,edgedegreedistribut:10,edgedomain:8,edgemap:1,edgescan:8,edgesdomain:[1,8],edgesmap:[1,9],edgeswithdegre:4,edgewrappereindextyp:1,eduplicatehistogram:1,effect:14,effort:17,eindextyp:1,element:[1,17],els:9,elt:[15,17],elttyp:[15,17],emc:8,emcdom:8,empti:11,enabl:[1,14],endprofil:14,enough:12,enqueu:17,entir:[8,14],epropmap:1,eproptyp:1,eqclass:7,eqclassesdom:7,equival:[1,7,12],equivalenceclass:0,erdo:8,evalu:14,even:12,evenli:17,everi:[1,4],everyth:9,exampl:[1,12],except:14,exist:[1,4,11],expand:2,experi:2,explicit:[1,6],explicitli:[1,6],fals:[1,2,3,4,11,14],fast:1,fetch:4,few:1,file:[1,14],filenam:[1,16],find:17,finish:12,first:[4,13],flush:[1,6,9,17],flushbuff:1,flushglob:[2,6,11],flushloc:[2,6,11,17],followthi:[1,2],foral:[1,9],format:16,forward:[1,9],found:11,from:[1,8],fromadjacencylist:1,full:13,furthermor:17,futur:14,gener:[0,1,7],generatebt:8,generatechunglu:8,generatechungluadjust:8,generatechungluprescansmp:8,generatechunglusmp:8,generateerdosrenyi:8,generateerdosrenyismp:8,generationseedoffset:8,generationuseaggreg:8,get:6,get_nb:14,getaddr:14,getadjacentvertic:4,getarrai:[2,6,15],getcandid:7,getdomain:2,getedg:[1,9],getedgebutterfli:4,getedgecaterpillar:4,getedgecompon:10,getedgecomponentmap:10,getedgedegre:1,getedgemetamorphcoef:4,getedgeperdegreemetamorphosiscoeffici:4,getequivalenceclass:7,getinclus:1,getinclusionmetamorphcoef:4,getinclusionnumbutterfli:4,getinclusionnumcaterpillar:4,getlin:14,getlocal:[1,14],getlocaleid:14,getnodeid:14,getprivatizedinst:[2,6,12,17],getproperti:[1,11],getptr:2,getstatist:12,gettoplex:1,getvertexbutterfli:4,getvertexcaterpillar:4,getvertexcompon:10,getvertexdegre:1,getvertexmetamorphcoef:4,getvertexperdegreemetamorphosiscoeffici:4,getvertic:1,getwork:17,given:[1,4,12],globals:17,goe:14,graph:[0,1,8],graphimpl:9,graphviz:16,group:10,growthrat:15,half:1,handl:6,hasedg:9,hash:11,hasinclus:1,hastermin:12,have:[1,4,6,12,13,17],help:17,henc:[1,12,14],here:17,high:14,higher:12,highest:4,histogram:[1,8,10],hold:6,hyperedg:[1,8,10],ideal:17,ident:7,identifi:1,idtyp:1,idx:[2,8,14,15],implement:[9,12,13],implicit:[1,14],incid:1,includ:[4,8,14],inclus:4,inclusionstoadd:8,increas:[12,17],increment:12,index:[0,1,2,4],init:[1,2,6,7,8,9,11,12,14,15,17],initi:11,inplac:1,input:4,insertaggreg:9,instanc:[1,2,6,9,12,14,17],instead:1,integ:[1,4],integr:[1,2,4,8,9,14,15],intent:12,intern:11,intersect:[1,9,10,14,15],intersections:[1,9,14,15],intersectionsizeatleast:14,invalidatecach:9,invok:[1,2],involv:12,iscachevalid:9,isconnect:1,isempti:17,isiniti:[2,6,11,17],isol:1,isshutdown:17,issu:6,item:8,iter:[1,2,4,6,7,9,10,11,13,14,15,17],iterkind:[1,2,4,6,7,9,11,14,15,17],itself:[1,14],just:12,kei:[7,11],keytyp:7,keytypeequival:7,keytypeequivalencecmptyp:7,larg:1,least:[1,4,10,14],left:12,less:17,level:8,lifetim:14,like:17,link:13,list:[1,4,13],loc:[2,6,17],local:[1,2,6,8,11,12,14,17],localespac:6,localproperti:11,locat:12,locid:[2,6,17],lock:[6,11],loop:1,low:14,lower:12,magnitud:13,main:[3,7,16,17],maintain:1,make:[6,12],makerandomstream:14,map:[1,9,10,11],mapper:11,mappertyp:11,matrix:1,maxbackoff:12,maximum:4,maxparallelsegmentspac:17,maxtaskpar:17,memori:1,metamorphosi:4,method:[2,14],metric:0,minbackoff:12,minimum:10,modul:0,mostli:14,msg:[2,6],msgtype:[2,6],multbackoff:12,multipl:[1,12],must:[1,2,8,12,14],mutabl:8,naiv:1,name:1,narg:[2,3],need:[6,13],neighbor:[1,4,9],neighborlist:4,never:6,nextstartidxdeq:17,nextstartidxenq:17,node:[12,14],nodedata:1,nodetyp:1,nodetypewrapp:1,nodetypewrapperidtyp:1,nop:1,nor:11,normal:1,note:[1,13,14],now:1,num_edg:8,num_vertic:8,numaggregatedwork:17,number:[1,4,8,10],numedg:[1,9],numer:4,numinclus:8,numoper:8,numproperti:11,numpropertiesglob:11,numrandom:8,numvertic:[1,9],object:[1,4],obtain:[1,10,11,14],occur:[12,14],offer:13,onc:12,onli:14,open:6,oper:1,optim:[1,14],order:13,origin:[1,11,14],other:[1,2,6,7,8,9,11,12,15,17],our:17,out:[14,16],over:[2,8,10],overhead:1,overlap:17,overrid:15,overwrit:11,own:[6,12],page:0,pair:1,param:[1,2,3,4,6,7,8,9,11,14,15,17],parent:12,partial:6,particip:1,pass:1,pattern:13,per:4,perform:[1,8,10,11,12],pid:[2,6,9,12,14,17],placement:17,point:1,polici:11,pool:2,possibl:[4,6],print:14,printdebuginform:14,privat:[1,11,12,14],privatizedcachedneighborlistinst:9,privatizedcachedneighborlistpid:9,probabl:8,probtabl:8,proc:[1,2,3,4,6,7,8,9,10,11,12,14,15,16,17],profilecommdiagnost:14,profilecommdiagnosticsverbos:14,profilevisualdebug:14,progress:[1,6],properti:[1,11],propertymap:[0,1],propertymapimpl:11,propertytyp:11,propertytypepropertymap:11,prototyp:9,provid:1,pure:1,queri:4,queue:17,raddr:14,randint:14,randreal:14,randvalu:8,rang:[4,14],rather:1,read:1,reader:1,readwritethi:[1,2,7,15],real:[4,8,14,15],record:[1,2,6,8,9,11,12,14,17],recycl:2,reduc:12,reduceeqclass:7,reducescanop:7,reduct:[7,12],ref:[1,2,7,8,12,14,15,17],refer:[1,11,14],regard:1,releas:6,remot:[2,12,14],remov:[1,17],removedupl:1,removeisolatedcompon:1,renyi:8,repres:[1,4],request:6,requir:13,respect:[1,12],result:[1,11],right:12,rng:14,rngoffset:8,rngseed:8,robin:17,round:17,safe:1,same:[1,10,11,12],scope:14,search:[0,13],second:4,segment:17,self:2,send:6,sent:6,separ:1,sequenc:[1,8],sequenti:1,serial:11,serv:1,set:[1,8,11],setproperti:11,sever:1,shallow:[1,11],share:[1,4],should:[1,9],shutdown:17,shutdownsign:17,side:14,significantli:10,similar:1,simpl:9,simplifi:[1,9],sink:1,size:[1,2,6,10,14,15,17],size_t:14,slower:10,sort:[8,15],sourc:1,spawn:12,speedup:13,start:12,startaggreg:1,startidx:[1,14],startidxdeq:17,startidxenq:17,state:7,statement:1,still:[1,14],stopaggreg:1,storag:1,store:[1,4],strictli:1,string:[1,3,14],subject:2,subset:[1,8],sum:1,superset:1,support:9,tag:[1,2,4,6,7,9,11,14,15,17],target:4,targetloc:8,targetlocal:[2,8],task:[6,12],tasksfinish:12,tasksstart:12,term:[1,12],termin:[12,13],terminationdetect:0,terminationdetector:[12,17],terminationdetectorimpl:12,test:4,than:[1,10,12],thei:[1,17],them:[1,10],thi:[1,2,4,6,7,8,10,11,13,14,15],thread:1,through:1,time:[1,12],todo:2,toedg:1,toplex:1,tovertex:1,travers:0,treat:14,truth:4,twice:12,two:[1,4,8,12,14],type:[1,2,4,6,7,9,11,14,15,17],typeindex:14,uint:17,unaffect:14,undefin:2,under:4,underli:9,uniform:9,uniniti:11,uninitializedaggreg:[2,6,9,17],uninitializeddynamicaggreg:[6,17],uninitializedpropertymap:11,uninitializedworkqueu:17,unmanag:[1,2,6,7,9,12,17],unrol:13,until:6,updat:[1,12],user:[1,2,6,14],util:0,valid:1,validatecach:9,valu:[4,7,11,14],vddom:8,vdebug:14,vdebugnam:14,vdegseq:8,vdegseqdom:8,vdesc:1,vdesctyp:[1,4,9,13],vduplicatehistogram:1,vector:[0,9],vectorgrowthr:15,vectorimpl:15,veri:12,verifi:1,version:1,vertex:[1,4,8,10],vertexbf:13,vertexcomponentsizedistribut:10,vertexdegreedistribut:10,vertexdomain:8,vertexhasneighbor:4,vertexmap:1,vertexscan:8,vertexwrappervindextyp:1,vertic:[1,4,8,10],verticesdomain:[1,8,9],verticesmap:[1,9],verticeswithdegre:4,via:1,vindextyp:1,visit:12,visitor:13,visual:0,vmc:8,vmcdom:8,vpropmap:1,vproptyp:1,wai:1,walk:[1,10],warn:14,weightedrandomsampl:8,when:[6,11],where:[1,4,17],whether:[1,11,12,14],which:[1,8,11,12,14],within:[1,4],without:[1,4,14],work:[1,17],workinfo:8,workqueu:0,workqueueimpl:17,workqueueinitialblocks:17,workqueuemaxblocks:17,workqueuemaxtightspincount:17,workqueuemintightspincount:17,workqueueminvelocityforflush:17,workqueuenoaggreg:17,workqueueunlimitedaggreg:17,worktyp:17,would:1,wq1:17,wq2:17,wrapper:[1,14],yield:[1,4],you:1},titles:["chpldoc documentation","AdjListHyperGraph","AggregationBuffer","BinReader","Butterfly","CHGL","DynamicAggregationBuffer","EquivalenceClasses","Generation","Graph","Metrics","PropertyMaps","TerminationDetection","Traversal","Utilities","Vectors","Visualize","WorkQueue"],titleterms:{adjlisthypergraph:1,aggregationbuff:2,binread:3,butterfli:4,chgl:5,chpldoc:0,distribut:1,document:0,dual:1,dynamicaggregationbuff:6,equivalenceclass:7,gener:8,global:1,graph:9,hypergraph:1,indic:0,metric:10,parallel:1,propertymap:11,tabl:0,terminationdetect:12,travers:13,usag:1,util:14,vector:15,view:1,visual:16,workqueu:17}})