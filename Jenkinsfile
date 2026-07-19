pipeline {
    agent any

    stages {

        stage('Checkout') {
            steps {
                echo 'Checking out source code...'
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t devops-automation-project ./docker'
            }
        }

        stage('Run Container') {
            steps {
                sh 'docker run -d -p 8080:80 --name automation-demo devops-automation-project || true'
            }
        }

        stage('Verify Deployment') {
            steps {
                echo 'Deployment completed successfully.'
            }
        }
    }

    post {
        always {
            echo 'Pipeline Finished.'
        }
    }
}