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
                    docker build -t cloud-pak-deployer:test .
                    docker tag cloud-pak-deployer:test quay.io/devplayground/cloud-pak-deployer:test
                    docker push quay.io/devplayground/cloud-pak-deployer:test"""
            }
        }
    }

    post { 
        always {
            cleanWs()
        }
    }
}
