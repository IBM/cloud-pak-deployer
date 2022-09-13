pipeline {
    agent any

    stages {
        stage('Build CP Deployer') {
            environment {
                QUAY_CREDS = credentials('quay')
            }
            steps {
                sh label: 'Build Image', script: """
                    echo $QUAY_CREDS_PSW | docker login -u=$QUAY_CREDS_USR --password-stdin quay.io
                    docker build -t cloud-pak-deployer:latest .
                    docker tag cloud-pak-deployer:latest quay.io/devplayground/cloud-pak-deployer:latest
                    docker push quay.io/devplayground/cloud-pak-deployer:latest"""
            }
        }
    }

    post { 
        always {
            cleanWs()
        }
    }
}
