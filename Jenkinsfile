pipeline {
  agent any

  parameters {
    choice(
      name: 'DEPLOY_TARGET',
      choices: ['ec2', 'eks'],
      description: 'Deployment target'
    )
    booleanParam(
      name: 'INSTALL_MONITORING',
      defaultValue: false,
      description: 'Install Prometheus/Grafana monitoring stack'
    )
  }

  environment {
    AWS_DEFAULT_REGION = 'ap-south-1'
    ECR_REPO = '<AWS_ACCOUNT_ID>.dkr.ecr.ap-south-1.amazonaws.com/taskops'
    EC2_HOST = '<EC2_PUBLIC_DNS_OR_IP>'
    EC2_USER = 'ec2-user'
    DOCKER_HUB_USER = '<DOCKER_HUB_USER>'
    GIT_SHORT_SHA = "${env.GIT_COMMIT.take(7)}"
    IMAGE_TAG = "${GIT_SHORT_SHA}"
    IMAGE_LATEST = "latest"
  }

  options {
    timeout(time: 30, unit: 'MINUTES')
    timestamps()
  }

  stages {
    stage('Checkout') {
      steps {
        echo 'Checking out code from repository...'
        checkout scm
      }
    }

    stage('Node Tests') {
      steps {
        echo 'Running tests inside node:18-alpine container...'
        script {
          sh '''
            docker run --rm \
              -v ${WORKSPACE}:/workspace \
              -w /workspace \
              node:18-alpine \
              sh -c "npm ci && npm test"
          '''
        }
      }
    }

    stage('Docker Build & Tag') {
      steps {
        script {
          echo "Building Docker image with tags: ${IMAGE_TAG} and ${IMAGE_LATEST}"
          sh """
            docker build -t taskops:${IMAGE_TAG} .
            docker tag taskops:${IMAGE_TAG} taskops:${IMAGE_LATEST}
          """
        }
      }
    }

    stage('Login & Push') {
      steps {
        script {
          // Determine which registry to push to based on deploy target
          if (params.DEPLOY_TARGET == 'eks') {
            // Push to ECR
            echo 'Logging into AWS ECR...'
            withCredentials([aws(credentialsId: '<JENKINS_CRED_ID:aws-creds>', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
              sh """
                aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | \
                  docker login --username AWS --password-stdin ${ECR_REPO.split('/')[0]}
              """
              sh """
                docker tag taskops:${IMAGE_LATEST} ${ECR_REPO}:${IMAGE_TAG}
                docker tag taskops:${IMAGE_LATEST} ${ECR_REPO}:${IMAGE_LATEST}
                docker push ${ECR_REPO}:${IMAGE_TAG}
                docker push ${ECR_REPO}:${IMAGE_LATEST}
              """
            }
          } else {
            // Push to Docker Hub (optional)
            echo 'Logging into Docker Hub...'
            withCredentials([usernamePassword(credentialsId: '<JENKINS_CRED_ID:dockerhub-creds>', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
              sh """
                echo ${DOCKER_PASSWORD} | docker login -u ${DOCKER_USERNAME} --password-stdin
              """
              sh """
                docker tag taskops:${IMAGE_LATEST} ${DOCKER_HUB_USER}/taskops:${IMAGE_TAG}
                docker tag taskops:${IMAGE_LATEST} ${DOCKER_HUB_USER}/taskops:${IMAGE_LATEST}
                docker push ${DOCKER_HUB_USER}/taskops:${IMAGE_TAG}
                docker push ${DOCKER_HUB_USER}/taskops:${IMAGE_LATEST}
              """
            }
          }
        }
      }
    }

    stage('Deploy') {
      steps {
        script {
          if (params.DEPLOY_TARGET == 'ec2') {
            echo 'Deploying to EC2 using Docker Compose...'
            
            // Copy docker-compose.yml to EC2
            sshagent(credentials: ['<JENKINS_CRED_ID:ec2-ssh>']) {
              sh """
                scp deploy/ec2/docker-compose.yml ${EC2_USER}@${EC2_HOST}:/tmp/taskops-compose.yml
              """
              
              // Login to registry and pull image
              if (params.DEPLOY_TARGET == 'ec2') {
                withCredentials([usernamePassword(credentialsId: '<JENKINS_CRED_ID:dockerhub-creds>', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
                  sh """
                    ssh ${EC2_USER}@${EC2_HOST} "
                      echo ${DOCKER_PASSWORD} | docker login -u ${DOCKER_USERNAME} --password-stdin
                      docker pull ${DOCKER_HUB_USER}/taskops:${IMAGE_LATEST}
                      TASKOPS_IMAGE=${DOCKER_HUB_USER}/taskops:${IMAGE_LATEST} docker compose -f /tmp/taskops-compose.yml up -d
                    "
                  """
                }
              }
            }
            
          } else if (params.DEPLOY_TARGET == 'eks') {
            echo 'Deploying to EKS using Terraform and Helm...'
            
            // Provision/update EKS infrastructure
            dir('infra/terraform') {
              withCredentials([aws(credentialsId: '<JENKINS_CRED_ID:aws-creds>', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                sh """
                  terraform init
                  terraform apply -auto-approve
                """
              }
            }
            
            // Update kubeconfig
            withCredentials([aws(credentialsId: '<JENKINS_CRED_ID:aws-creds>', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
              sh """
                aws eks update-kubeconfig --region ${AWS_DEFAULT_REGION} --name ${sh(script: 'cd infra/terraform && terraform output -raw cluster_name', returnStdout: true).trim()}
              """
            }
            
            // Install/upgrade Helm chart
            sh """
              helm upgrade --install taskops charts/taskops \
                --namespace taskops --create-namespace \
                --set image.repository=${ECR_REPO} \
                --set image.tag=${IMAGE_LATEST} \
                --set service.type=LoadBalancer \
                --wait --timeout 5m
            """
            
            // Install monitoring if requested
            if (params.INSTALL_MONITORING) {
              echo 'Installing Prometheus/Grafana monitoring stack...'
              sh """
                helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
                helm repo update
                helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
                  --namespace monitoring --create-namespace \
                  --wait --timeout 5m
              """
            }
          }
        }
      }
    }

    stage('Smoke Tests') {
      steps {
        script {
          if (params.DEPLOY_TARGET == 'ec2') {
            echo 'Running smoke tests on EC2 deployment...'
            sh """
              curl -f http://${EC2_HOST}:8000/healthz
              curl -f http://${EC2_HOST}:8000/metrics | head -20
            """
          } else if (params.DEPLOY_TARGET == 'eks') {
            echo 'Running smoke tests on EKS deployment...'
            sh """
              # Get LoadBalancer hostname
              LB_HOST=$(kubectl get svc taskops -n taskops -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
              
              if [ -z "$LB_HOST" ]; then
                echo "LoadBalancer not ready, using port-forward fallback..."
                kubectl port-forward -n taskops svc/taskops 8000:8000 &
                sleep 5
                curl -f http://localhost:8000/healthz
                curl -f http://localhost:8000/metrics | head -20
                pkill -f "kubectl port-forward"
              else
                echo "Testing via LoadBalancer: $LB_HOST"
                curl -f http://$LB_HOST:8000/healthz
                curl -f f http://$LB_HOST:8000/metrics | head -20
              fi
            """
          }
        }
      }
    }
  }

  post {
    always {
      echo 'Cleaning up Docker images...'
      sh 'docker image prune -f || true'
    }
    success {
      echo 'Pipeline completed successfully!'
      archiveArtifacts artifacts: 'infra/terraform/terraform.tfstate*', allowEmptyArchive: true
    }
    failure {
      echo 'Pipeline failed. Check logs for details.'
    }
  }
}
