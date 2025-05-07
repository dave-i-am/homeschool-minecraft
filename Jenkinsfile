pipeline {
    agent { label 'docker-agent' } // Must match your Docker cloud agent label

    environment {
        COMPOSE_FILE = 'docker-compose.yml' // Adjust as needed
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Images') {
            steps {
                sh 'docker-compose -f $COMPOSE_FILE build'
            }
        }

        stage('Start Services') {
            steps {
                sh 'docker-compose -f $COMPOSE_FILE up -d'
            }
        }

        stage('Run Tests') {
            steps {
                // Replace with your test command
                sh 'docker-compose -f $COMPOSE_FILE exec -T app ./run-tests.sh'
            }
        }

        stage('Teardown') {
            steps {
                sh 'docker-compose -f $COMPOSE_FILE down --volumes'
            }
        }
    }

    post {
        always {
            echo 'Cleaning up...'
            sh 'docker-compose -f $COMPOSE_FILE down --volumes || true'
        }
    }
}
