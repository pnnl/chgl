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
                    sh 'ssh puma.pnl.gov rm -rf $CHGL_WORKSPACE'
                    sh 'scp -r $WORKSPACE puma.pnl.gov:$CHGL_WORKSPACE'

                    // SSH to puma.pnl.gov and execute jenkins-build.sh
                    sh 'ssh puma.pnl.gov "chmod 755 $CHGL_WORKSPACE/jenkins-build.sh"'
                    sh 'ssh puma.pnl.gov "bash -l -c $CHGL_WORKSPACE/jenkins-build.sh"'

                    // Get results back from puma.pnl.gov
                    sh 'scp -r puma.pnl.gov:$CHGL_WORKSPACE/test_performance/Logs $WORKSPACE/test_performance'
                    sh 'scp -r puma.pnl.gov:$CHGL_WORKSPACE/test_performance/dat $WORKSPACE/test_performance'
                }
                sshagent (['40cddb85-453e-48cc-850e-942ca9edab7c']) {
                    // Push CHGL performance graphs to gh-pages
                    sh '''
                        cd $WORKSPACE/test_performance/dat
                        rm -rf tmp
                        mkdir -p tmp
                        cd tmp
                        git clone -b gh-pages --single-branch https://github.com/pnnl/chgl-perf.git
                        cd chgl-perf
                        cp -ar $WORKSPACE/test_performance/dat/html/. .
                        git add .
                        git commit -m "Performance Test Update"
                        git push
                        cd ../..
                        rm -rf tmp
                    '''
                }
            }
            post {
                always { 
                    archiveArtifacts artifacts: 'test_performance/**/dat/**/*.*'
                    junit 'test_performance/**/Logs/*.xml' 
                    perfReport 'test_performance/**/Logs/*.xml'
                }
            }
        }
    }
}
