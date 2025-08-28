pipeline {
  agent any

  options {
    skipDefaultCheckout(false)
    timestamps()
  }

  environment {
    AWS_REGION          = 'ap-south-1'
    ECR_ACCOUNT_ID      = '982081054052'
    ECR_REPO_NAME       = 'cloudnativewebapi'
    ECR_REGISTRY        = "${ECR_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    IMAGE_TAG           = "${env.BUILD_NUMBER}"
    DOCKER_IMAGE        = "${ECR_REGISTRY}/${ECR_REPO_NAME}:${IMAGE_TAG}"
    DOCKER_IMAGE_LATEST = "${ECR_REGISTRY}/${ECR_REPO_NAME}:latest"
  }

  stages {

    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Setup .NET SDK') {
      steps {
        ansiColor('xterm') {
          sh 'dotnet --info || true'
        }
      }
    }

    stage('Restore & Build') {
      steps {
        ansiColor('xterm') {
          sh '''
            set -e
            dotnet restore
            dotnet build --configuration Release --no-restore
          '''
        }
      }
    }

    stage('Test') {
      steps {
        ansiColor('xterm') {
          sh '''
            set -e
            for proj in $(find . -name "*Tests.csproj"); do
              echo "Running tests in $proj"
              dotnet test "$proj" --configuration Release --no-build --logger "trx;LogFileName=test_results.trx"
            done
          '''
        }
      }
      post {
        always {
          junit allowEmptyResults: true, testResults: '**/TestResults/*.xml, **/TestResults/*.trx'
        }
      }
    }

    stage('Docker Build') {
      steps {
        ansiColor('xterm') {
          sh '''
            set -e
            if [ -f ./Dockerfile ]; then
              DOCKERFILE=./Dockerfile
              CONTEXT=.
            else
              DOCKERFILE=$(git ls-files | grep -i "/Dockerfile$" | head -n1)
              CONTEXT=$(dirname "$DOCKERFILE")
            fi
            echo "Using Dockerfile=$DOCKERFILE context=$CONTEXT"
            docker build -f "$DOCKERFILE" -t "${DOCKER_IMAGE}" -t "${DOCKER_IMAGE_LATEST}" "$CONTEXT"
          '''
        }
      }
    }

    stage('ECR Login and Push') {
      steps {
        withCredentials([[ $class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds' ]]) {
          ansiColor('xterm') {
            sh '''
              set -e
              aws --version
              aws ecr get-login-password --region "${AWS_REGION}" \
                | docker login --username AWS --password-stdin "${ECR_REGISTRY}"
              aws ecr describe-repositories --repository-names "${ECR_REPO_NAME}" --region "${AWS_REGION}" \
              || aws ecr create-repository --repository-name "${ECR_REPO_NAME}" --region "${AWS_REGION}"
              docker push "${DOCKER_IMAGE}"
              docker push "${DOCKER_IMAGE_LATEST}"
            '''
          }
        }
      }
    }

    stage('Deploy to ECS') {
      steps {
        withCredentials([[ $class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds' ]]) {
          ansiColor('xterm') {
            sh '''
              set -e
              CLUSTER_NAME="cloudnativewebapi-cluster"
              SERVICE_NAME="cloudnativewebapi-service"
              TASK_FAMILY="cloudnativewebapi-task"   # must match Terraform

              # Get latest ACTIVE task def JSON for the family
              BASE_TD=$(aws ecs describe-task-definition \
                --task-definition "$TASK_FAMILY" \
                --region "${AWS_REGION}" \
                --query 'taskDefinition' \
                --output json)

              # Update image and strip read-only fields
              echo "$BASE_TD" | jq \
                --arg IMG "${DOCKER_IMAGE}" '
                  .containerDefinitions |= map(.image = $IMG)
                  | del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy)
                ' > task-updated.json

              # Register new revision
              NEW_TD_ARN=$(aws ecs register-task-definition \
                --cli-input-json file://task-updated.json \
                --region "${AWS_REGION}" \
                --query 'taskDefinition.taskDefinitionArn' \
                --output text)

              # Update service to new revision
              aws ecs update-service \
                --cluster "$CLUSTER_NAME" \
                --service "$SERVICE_NAME" \
                --task-definition "$NEW_TD_ARN" \
                --region "${AWS_REGION}"

              echo "Deployed task: $NEW_TD_ARN"
            '''
          }
        }
      }
    }
  }

  post {
    always {
      cleanWs(deleteDirs: true, notFailBuild: true)
    }
  }
}
