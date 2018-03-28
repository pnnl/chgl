pipeline {
    agent { dockerfile true }
    stages {
        stage('Unit Test') {
            steps {
                sh 'cd test/unit && start_test -junit-xml -junit-xml-file ${WORKSPACE}/test/Logs/chapel-unit-tests.xml -numlocales 4'
            }
            post {
                always { 
                    junit 'test/Logs/*.xml' 
                    perfReport 'test/Logs/*.xml'
                }
            }
        }
        stage('Performance Test') {
            steps {
                sh 'export CHPL_TEST_PERF_DIR=${WORKSPACE}/test/performance/dat && mkdir -p $CHPL_TEST_PERF_DIR && cd test/performance && start_test --performance -junit-xml -junit-xml-file ${WORKSPACE}/test/Logs/chapel-perf-tests.xml -numlocales 4'
            }
            post {
                always { 
                    junit 'test/Logs/*.xml' 
                    perfReport 'test/Logs/*.xml'
                }
            }
        }
    }
}