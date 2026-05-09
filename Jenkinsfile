pipeline {
  agent any

  options {
    timestamps()
    ansiColor('xterm')
  }

  environment {
    AWS_REGION = 'us-east-1'
    TF_WORKING_DIR = 'infra/terraform/environments/prod'
    IMAGE_NAME = 'damolak-devops-demo'
    TF_STATE_KEY = 'damolak-devops-demo/prod/terraform.tfstate'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Test') {
      steps {
        sh 'npm test'
      }
    }

    stage('Build Image') {
      steps {
        script {
          env.IMAGE_TAG = env.GIT_COMMIT
        }
        sh 'docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .'
      }
    }

    stage('Terraform Format') {
      steps {
        sh 'terraform fmt -check -recursive'
      }
    }

    stage('Terraform Init') {
      steps {
        withCredentials([
          string(credentialsId: 'tf-state-bucket', variable: 'TF_STATE_BUCKET')
        ]) {
          dir("${TF_WORKING_DIR}") {
            sh '''
              terraform init \
                -backend-config="bucket=${TF_STATE_BUCKET}" \
                -backend-config="key=${TF_STATE_KEY}" \
                -backend-config="region=${AWS_REGION}"
            '''
          }
        }
      }
    }

    stage('Terraform Validate') {
      steps {
        dir("${TF_WORKING_DIR}") {
          sh 'terraform validate'
        }
      }
    }

    stage('Deploy') {
      when {
        branch 'main'
      }
      steps {
        withCredentials([
          string(credentialsId: 'tf-state-bucket', variable: 'TF_STATE_BUCKET')
        ]) {
          dir("${TF_WORKING_DIR}") {
            sh 'terraform apply -target=module.ecr -auto-approve'
            script {
              env.REPOSITORY_URL = sh(
                script: 'terraform output -raw ecr_repository_url',
                returnStdout: true
              ).trim()
            }
          }

          sh '''
            aws ecr get-login-password --region "${AWS_REGION}" \
              | docker login --username AWS --password-stdin "${REPOSITORY_URL}"
            docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${REPOSITORY_URL}:${IMAGE_TAG}"
            docker push "${REPOSITORY_URL}:${IMAGE_TAG}"
          '''

          dir("${TF_WORKING_DIR}") {
            sh 'terraform apply -auto-approve -var="image_tag=${IMAGE_TAG}"'
          }
        }
      }
    }
  }
}
