# Running Chapel Hypergraph Library Unit Tests
We use the Chapel `start_test` Python script to execute unit tests. 

Each test needs a `<TestName>.chpl` file with executable Chapel code to test your unit of work. The paired `<TestName>.good` file is the expected stdout that is compared to the actual to determine if the test passes. The Jenkins and GitLab builds are configured to run all `.chpl` files found in the `test/unit` folder.

If you want to manually run an individual unit test, execute `start_test <fileName>.chpl`.

See these links for more information
* <https://github.com/chapel-lang/chapel/issues/7495> 
* <https://github.com/chapel-lang/chapel/blob/master/util/start_test> 
* <https://github.com/chapel-lang/chapel/blob/master/test/release/examples/README.testing>
* <https://github.com/chapel-lang/chapel/blob/master/doc/rst/developer/bestPractices/TestSystem.rst>