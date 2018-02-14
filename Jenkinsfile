pipeline {
    agent { dockerfile true }
    stages {
        stage('Test') {
            steps {
                sh 'cd test'
                sh 'start_test -junit-xml -numlocales 4'
            }
        }
    }
}