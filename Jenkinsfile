pipeline {
    stages {
        stage('Performance Test') {
            steps {
                sshagent (['250e32c1-122e-43f7-953d-46324a8501b9']) {
                    // Send workspace to puma.pnl.gov
                    scp -r $WORKSPACE jenkins@puma.pnl.gov:workspace/

                    // SSH to puma.pnl.gov and execute jenkins-build.sh
                    ssh jenkins@puma.pnl.gov workspace/jeknins-build.sh

                    // Get results back from puma.pnl.gov
                    scp -r jenkins@puma.pnl.gov:workspace/ $WORKSPACE/
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