pipeline {
    agent { dockerfile true }
    stages {
        stage('Test') {
            steps {
                sh 'cd test && start_test -junit-xml -junit-xml-file /var/lib/jenkins/jenkins-home/workspace/HPDA/AHM/chgl/test/Logs/chapel-tests.xml -numlocales 4'
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