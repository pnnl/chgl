pipeline {
    agent { dockerfile true }
    stages {
        stage('Unit Test') {
            steps {
                sh 'cd test/unit && start_test -junit-xml -junit-xml-file /var/lib/jenkins/jenkins-home/workspace/HPDA/AHM/chgl/test/Logs/chapel-unit-tests.xml -numlocales 4'
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
                sh 'export CHPL_TEST_PERF_DIR=/var/lib/jenkins/jenkins-home/workspace/HPDA/AHM/chgl/test/performance/dat && mkdir $CHPL_TEST_PERF_DIR && cd test/performance && start_test --performance -junit-xml -junit-xml-file /var/lib/jenkins/jenkins-home/workspace/HPDA/AHM/chgl/test/Logs/chapel-perf-tests.xml -numlocales 4'
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