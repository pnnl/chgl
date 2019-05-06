# Running Chapel Hypergraph Library Performance Tests
We use the Chapel `start_test --performance` Python script to execute unit tests. 

Performance tests should be separate from unit tests (see `test/unit` folder for unit tests). This separates the concerns of testing and allows us to more easily maintain the two. 

The `<TestName>.good` file will likely be empty, as software concerned with high performance will likely have no output to compare. However, the `<TestName>.chpl` file will still need to perform some `writeln('...')` calls to output the performance metrics -- e.g., execution time and memory usage. 

The paired `<TestName>.perfkeys` file lists those performance metrics output for Chapel's testing framework to retrieve and store in its `<TestName>.dat` files, keeping records of performance over time. Though in the case of tests run in Jenkins and GitLab these metrics are handled separately as the build workspaces will likely be wiped out each build. *TODO: document where the performance trends are in the build systems, consider Chapel's GRAPHFILES support*

If you want to manually run an individual performance test, execute `start_test --performance <fileName>.chpl`.

# NOTES
On a Fedora 27 system, I had to install glibc-static and libstdc++-static before the `--static` flag used by the performance test compilation linked properly. YMMV

See these links for more information
* <https://github.com/chapel-lang/chapel/tree/master/test/studies/parboil/BFS> 
* <https://github.com/chapel-lang/chapel/blob/master/util/start_test> 
* <https://github.com/chapel-lang/chapel/blob/master/test/release/examples/README.testing>
* <https://github.com/chapel-lang/chapel/blob/master/doc/rst/developer/bestPractices/TestSystem.rst#performance-tests>