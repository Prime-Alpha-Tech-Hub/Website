pipeline {
    agent any

    environment {
        EC2_USER = "ubuntu"
        EC2_HOST = "13.42.10.182"
        APP_DIR  = "/home/ubuntu/Prime-Alpha-Securities/my-app"
        PEM_KEY  = "webkey.pem"
    }

    stages {

        stage('Checkout Code') {
            steps {
                git(
                    branch: 'main',
                    credentialsId: 'github-token',
                    url: 'https://github.com/johanAurel/Prime-Alpha-Securities.git'
                )
            }
        }

        stage('Prepare SSH Key') {
            steps {
                sh '''
                chmod 600 ${PEM_KEY}
                '''
            }
        }

        stage('Package Project') {
            steps {
                sh '''
                echo "Preparing deployment package"

                rm -rf build
                mkdir build

                rsync -av \
                    --exclude node_modules \
                    --exclude dist \
                    --exclude build \
                    ./my-app/ build/
                '''
            }
        }

        stage('Upload to EC2') {
            steps {
                sh '''
                ssh -o StrictHostKeyChecking=no -i ${PEM_KEY} ${EC2_USER}@${EC2_HOST} "mkdir -p ${APP_DIR}"

                rsync -avz \
                    -e "ssh -i ${PEM_KEY} -o StrictHostKeyChecking=no" \
                    build/ \
                    ${EC2_USER}@${EC2_HOST}:${APP_DIR}/
                '''
            }
        }

        stage('Run Deploy Script') {
            steps {
                sh '''
                ssh -o StrictHostKeyChecking=no -i ${PEM_KEY} ${EC2_USER}@${EC2_HOST} "
                    cd ${APP_DIR} &&
                    chmod +x deploy.sh &&
                    sudo bash ./deploy.sh
                "
                '''
            }
        }
    }

    post {
        success {
            echo "Deployment completed successfully"
        }

        failure {
            echo "Deployment failed"
        }
    }
}
