pipeline {
    agent { label 'linux' }
    stages {
        stage('Performance Test') {
            environment {
                CHGL_WORKSPACE = '/lustre/jenkins/chgl-workspace'
            }
            steps {
                withCredentials([usernamePassword(credentialsId: 'bf9770c1-5df7-4d37-a800-10aff86fe0e0', passwordVariable: 'GIT_PASSWORD', usernameVariable: 'GIT_USERNAME')]) {
                    // Push CHGL performance graphs to gh-pages
                    sh '''
                        #!/bin/sh -e
                        cd $WORKSPACE/test_performance/dat
                        rm -rf tmp
                        mkdir -p tmp
                        cd tmp
                        git clone -b dat-files https://github.com/pnnl/chgl-perf.git
                        cd chgl-perf/dat-files
                        cp *.dat $WORKSPACE/test_performance/dat/
                        cd ../..
                        rm -rf tmp
                    '''
                }
                sshagent (['250e32c1-122e-43f7-953d-46324a8501b9']) {
                    // SSH to puma.pnl.gov and execute jenkins-build.sh
                    sh 'ssh puma.pnl.gov "chmod 755 $CHGL_WORKSPACE/jenkins-build.sh"'
                    sh 'ssh puma.pnl.gov "bash -l -c $CHGL_WORKSPACE/jenkins-build.sh"'

                    // Send workspace to puma.pnl.gov
                    sh 'ssh puma.pnl.gov rm -rf $CHGL_WORKSPACE'
                    sh 'scp -r $WORKSPACE puma.pnl.gov:$CHGL_WORKSPACE'
                }
                withCredentials([usernamePassword(credentialsId: 'bf9770c1-5df7-4d37-a800-10aff86fe0e0', passwordVariable: 'GIT_PASSWORD', usernameVariable: 'GIT_USERNAME')]) {
                    // Push CHGL performance graphs to gh-pages
                    sh '''
                        #!/bin/sh -e
                        cd $WORKSPACE/test_performance/dat
                        rm -rf tmp
                        mkdir -p tmp
                        cd tmp
                        git clone -b dat-files https://github.com/pnnl/chgl-perf.git
                        cd chgl-perf/dat-files
                        cp $WORKSPACE/test_performance/dat/*.dat .
                        git add -u
                        git commit -m "Dat files update"
                        git push https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/pnnl/chgl-perf.git
                        cd ..
                        git checkout gh-pages
                        cp -ar $WORKSPACE/test_performance/dat/html/. .
                        git add .
                        git commit -m "Performance Test Update"
                        git push https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/pnnl/chgl-perf.git
                        cd ../..
                        rm -rf tmp
                    '''
                }
                sshagent (['250e32c1-122e-43f7-953d-46324a8501b9']) {
                    // Get results back from puma.pnl.gov
                    sh 'scp -r puma.pnl.gov:$CHGL_WORKSPACE/test_performance/Logs $WORKSPACE/test_performance'
                    sh 'scp -r puma.pnl.gov:$CHGL_WORKSPACE/test_performance/dat $WORKSPACE/test_performance'
                }
            }
            post {
                always { 
                    // Steps before JUnit plugin may take long enough that Jenkins doesn't like the time difference
                    script {
                        def testResults = findFiles(glob: 'test_performance/**/Logs/*.xml')
                        for(xml in testResults) {
                            touch xml.getPath()
                        }
                    }
                    junit 'test_performance/**/Logs/*.xml' 
                    perfReport 'test_performance/**/Logs/*.xml'
                    archiveArtifacts artifacts: 'test_performance/**/dat/**/*.*'
                }
            }
        }
    }
}
