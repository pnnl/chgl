# Running Chapel Hypergraph Library Performance Tests
We use the relatively undocumented Chapel `start_test --performance` Python script to execute unit tests. 

See <https://github.com/chapel-lang/chapel/tree/master/test/studies/parboil/BFS> and <https://github.com/chapel-lang/chapel/blob/master/util/start_test> for more information.

*TODO: implement sample, add to builds, and document this more...*

If you want to manually run an individual performance test, execute `start_test --performance <fileName>.chpl`.