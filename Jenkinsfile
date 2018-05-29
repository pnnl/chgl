pipeline {
    agent { label 'linux' }
    stages {
        stage('Performance Test') {
            steps {
                sshagent (['250e32c1-122e-43f7-953d-46324a8501b9']) {
                    // Send workspace to puma.pnl.gov
                    sh 'ssh jenkins@puma.pnl.gov rm -rf chgl-workspace'
                    sh 'scp -r $WORKSPACE jenkins@puma.pnl.gov:chgl-workspace'

                    // SSH to puma.pnl.gov and execute jenkins-build.sh
                    //sh 'ssh jenkins@puma.pnl.gov workspace/jenkins-build.sh'
                    sh 'ssh jenkins@puma.pnl.gov export CHPL_TEST_PERF_DIR=/home/jenkins/chgl-workspace/test/performance/dat && cd /home/jenkins/chgl-workspace/test/performance && start_test --performance -junit-xml -junit-xml-file /home/jenkins/chgl-workspace/test/performance/Logs/chapel-perf-tests.xml -numlocales 4'

                    // Get results back from puma.pnl.gov
                    //sh 'scp -r jenkins@puma.pnl.gov:workspace/ $WORKSPACE/'
                }
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