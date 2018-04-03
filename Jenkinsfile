pipeline {
    agent { dockerfile true }
    stages {
        stage('Unit Test') {
            steps {
                sh 'cd test/unit && start_test -junit-xml -junit-xml-file ${WORKSPACE}/test/unit/Logs/chapel-unit-tests.xml -numlocales 4'
            }
            post {
                always { 
                    junit 'test/unit/Logs/*.xml' 
                    perfReport 'test/unit/Logs/*.xml'
                }
            }
        }
        stage('Performance Test') {
            steps {
                sh 'export CHPL_TEST_PERF_DIR=${WORKSPACE}/test/performance/dat && cd test/performance && start_test --performance -junit-xml -junit-xml-file ${WORKSPACE}/test/performance/Logs/chapel-perf-tests.xml -numlocales 4'

                // Generated HTML doesn't work from Jenkins due to https://wiki.jenkins.io/display/JENKINS/Configuring+Content+Security+Policy ... unsuccessful try to kludge a fix below
                //sh '#!/bin/bash \n' +
                //   'sed -i \\"s|\\x3C/head\\x3E|\\x3Cmeta http-equiv=\\x22Content-Security-Policy\\x22 content=\\x22default-src \\*; style-src \\x27self\\x27 \\x27unsafe-inline\\x27; script-src \\x27self\\x27 \\x27unsafe-inline\\x27 \\x27unsafe-eval\\x27 https://cdnjs.cloudflare.com/ \\x22\\x3E\\x3C/head\\x3E|\\" ${WORKSPACE}/test/performance/dat/html/index.html'
            }
            post {
                always { 
                    junit 'test/performance/Logs/*.xml' 
                    perfReport 'test/performance/Logs/*.xml'
                }
            }
        }
    }
}