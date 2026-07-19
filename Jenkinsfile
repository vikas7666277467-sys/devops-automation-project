pipeline {
    agent any

    environment {
        IMAGE_NAME = "devops-automation-project"
        CONTAINER_NAME = "automation-demo"
    }

    stages {

        stage('Checkout') {
            steps {
                echo 'Checking out source code...'
                checkout scm
            }
        }

        stage('Validate Project') {
            steps {
                sh 'test -f docker/Dockerfile'
                sh 'test -f docker-compose.yml'
                sh 'echo "Project validation successful."'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t $IMAGE_NAME ./docker'
            }
        }

        stage('Deploy Container') {
            steps {
                sh '''
                docker stop $CONTAINER_NAME || true
                docker rm $CONTAINER_NAME || true
                docker run -d \
                  --name $CONTAINER_NAME \
                  -p 8080:80 \
                  $IMAGE_NAME
                '''
            }
        }

        stage('Health Check') {
            steps {
                sh 'docker ps'
                echo 'Container is running successfully.'
            }
        }
    }

    post {
        success {
            echo 'CI/CD Pipeline Executed Successfully!'
        }

        failure {
            echo 'Pipeline Failed!'
        }

        always {
            cleanWs()
        }
    }
}