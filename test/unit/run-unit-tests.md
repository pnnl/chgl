# Running Chapel Hypergraph Library Unit Tests
We use the relatively undocumented Chapel `start_test` Python script to execute unit tests. 

See <https://github.com/chapel-lang/chapel/issues/7495> and <https://github.com/chapel-lang/chapel/blob/master/util/start_test> for more information.

Each test needs a .chpl file with executable Chapel code to test your unit of work. The paired .good file is the expected stdout that is compared to the actual to determine if the test passes. The Jenkins and GitLab builds are configured to run all .chpl files found in the test/unit folder.

If you want to manually run an individual unit test, execute `start_test <fileName>.chpl`.