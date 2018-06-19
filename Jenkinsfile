pipeline {
    agent { label 'linux' }
    stages {
        stage('Performance Test') {
            environment {
                CHGL_WORKSPACE = '/lustre/jenkins/chgl-workspace'
            }
            steps {
                sshagent (['250e32c1-122e-43f7-953d-46324a8501b9']) {
                    // Send workspace to puma.pnl.gov
                    sh 'ssh jenkins@puma.pnl.gov rm -rf $CHGL_WORKSPACE'
                    sh 'scp -r $WORKSPACE jenkins@puma.pnl.gov:$CHGL_WORKSPACE'

                    // SSH to puma.pnl.gov and execute jenkins-build.sh
                    sh 'ssh jenkins@puma.pnl.gov "bash -s" < jenkins-build.sh'

                    // Get results back from puma.pnl.gov
                    sh 'scp -r jenkins@puma.pnl.gov:$CHGL_WORKSPACE/test/unit/Logs $WORKSPACE/test/unit'
                    sh 'scp -r jenkins@puma.pnl.gov:$CHGL_WORKSPACE/test/performance/Logs $WORKSPACE/test/performance'
                    sh 'scp -r jenkins@puma.pnl.gov:$CHGL_WORKSPACE/test/performance/dat $WORKSPACE/test/performance'
                }
            }
            post {
                always { 
                    junit 'test/**/Logs/*.xml' 
                    perfReport 'test/**/Logs/*.xml'
                }
            }
        }
    }
}