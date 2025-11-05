pipeline {
  agent any

  // Trigger on Git push (webhook or polling)
  triggers {
    // Poll SCM every 2 minutes (alternative to webhook)
    pollSCM('H/2 * * * *')
  }

  parameters {
    choice(
      name: 'DEPLOY_TARGET',
      choices: ['eks'],
      description: 'Deployment target (EKS)'
    )
    booleanParam(
      name: 'INSTALL_MONITORING',
      defaultValue: true,
      description: 'Install Prometheus/Grafana monitoring stack'
    )
  }

  environment {
    AWS_DEFAULT_REGION = 'ap-south-1'
    AWS_ACCOUNT_ID = '483746227398'
    ECR_REPO = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/taskops"
    EKS_CLUSTER_NAME = 'taskops-k8s'
    DOCKER_HUB_USER = '<DOCKER_HUB_USER>'
    GIT_SHORT_SHA = "${env.GIT_COMMIT.take(7)}"
    IMAGE_TAG = "${GIT_SHORT_SHA}"
    IMAGE_LATEST = "latest"
    KUBECONFIG = "${WORKSPACE}/kubeconfig"
  }

  options {
    timeout(time: 30, unit: 'MINUTES')
    timestamps()
    disableConcurrentBuilds()  // Keep disabled to avoid resource exhaustion
    retry(1)  // Retry failed builds once
  }

  stages {

    stage('Preflight') {
      steps {
        script {
          if (!params.DEPLOY_TARGET) {
            error 'DEPLOY_TARGET is required'
          }
          if (params.DEPLOY_TARGET == 'eks' && ( !env.ECR_REPO || env.ECR_REPO.contains('<AWS_ACCOUNT_ID>') )) {
            error 'Set a real ECR_REPO, e.g. 123456789012.dkr.ecr.ap-south-1.amazonaws.com/taskops'
          }
          if (params.DEPLOY_TARGET == 'ec2' && ( !env.DOCKER_HUB_USER || env.DOCKER_HUB_USER.contains('<') )) {
            echo 'Note: DOCKER_HUB_USER not set; EC2 path expects Docker Hub pushes.'
          }
        }
        sh 'printenv | sort'
      }
    }

    stage('Checkout') {
      steps {
        echo 'Checking out code from repository...'
        checkout scm
        script {
          env.SHORT_SHA = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
          env.IMAGE_TAG = env.SHORT_SHA
          // Derive ECR registry (the hostname part before first '/')
          env.ECR_REGISTRY = env.ECR_REPO.contains('/') ? env.ECR_REPO.split('/')[0] : env.ECR_REPO
          echo "SHORT_SHA=${env.SHORT_SHA}, ECR_REGISTRY=${env.ECR_REGISTRY}"
        }
      }
    }

    stage('Node Tests') {
      steps {
        echo 'Running tests inside node:18-alpine container...'
        sh '''
          docker run --rm \
            -v "$PWD":/workspace \
            -w /workspace \
            node:18-alpine \
            sh -c "npm ci && npm test"
        '''
      }
    }

    stage('Docker Build & Tag') {
      steps {
        script {
          echo "Building Docker image with tags: ${env.IMAGE_TAG} and ${env.IMAGE_LATEST}"
        }
        sh """
          docker build -t taskops:${env.IMAGE_TAG} .
          docker tag taskops:${env.IMAGE_TAG} taskops:${env.IMAGE_LATEST}
        """
      }
    }

    stage('Login & Push to ECR') {
      steps {
        script {
          echo 'Logging into AWS ECR and pushing image...'
          withCredentials([aws(credentialsId: 'aws-creds', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
            sh """
              # Export AWS credentials
              export AWS_ACCESS_KEY_ID=\${AWS_ACCESS_KEY_ID}
              export AWS_SECRET_ACCESS_KEY=\${AWS_SECRET_ACCESS_KEY}
              export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}
              
              # Check if AWS CLI is installed and working (check multiple locations)
              AWS_CLI_PATH=""
              
              # First check if aws is in PATH and works
              if command -v aws > /dev/null 2>&1 && aws --version > /dev/null 2>&1; then
                AWS_CLI_PATH="aws"
              # Check common installation locations
              elif [ -f /usr/local/bin/aws ] && /usr/local/bin/aws --version > /dev/null 2>&1; then
                AWS_CLI_PATH="/usr/local/bin/aws"
                export PATH=/usr/local/bin:\$PATH
              elif [ -f /usr/local/aws/bin/aws ] && /usr/local/aws/bin/aws --version > /dev/null 2>&1; then
                AWS_CLI_PATH="/usr/local/aws/bin/aws"
                export PATH=/usr/local/aws/bin:\$PATH
              elif [ -f /var/lib/jenkins/.local/bin/aws ] && /var/lib/jenkins/.local/bin/aws --version > /dev/null 2>&1; then
                AWS_CLI_PATH="/var/lib/jenkins/.local/bin/aws"
                export PATH=/var/lib/jenkins/.local/bin:\$PATH
              else
                echo "AWS CLI not found. Installing AWS CLI v2 (user space, no sudo)..."
                mkdir -p /var/lib/jenkins/.local/bin
                cd /tmp
                curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip || { echo "Failed to download AWS CLI"; exit 1; }
                unzip -q awscliv2.zip || { echo "Failed to unzip AWS CLI"; exit 1; }
                ./aws/install -i /var/lib/jenkins/.local/aws-cli -b /var/lib/jenkins/.local/bin || { echo "Failed to install AWS CLI"; exit 1; }
                AWS_CLI_PATH="/var/lib/jenkins/.local/bin/aws"
                export PATH=/var/lib/jenkins/.local/bin:\$PATH
                cd -
              fi
              
              # Verify AWS CLI works
              if ! \$AWS_CLI_PATH --version > /dev/null 2>&1; then
                echo "AWS CLI verification failed. Path: \$AWS_CLI_PATH"
                echo "PATH: \$PATH"
                exit 1
              fi
              
              echo "Using AWS CLI at: \$AWS_CLI_PATH"
              \$AWS_CLI_PATH --version
              
              # Login to ECR
              ECR_REGISTRY="${ECR_REPO.split('/')[0]}"
              ECR_PASSWORD=\$(\$AWS_CLI_PATH ecr get-login-password --region ${AWS_DEFAULT_REGION})
              echo "\$ECR_PASSWORD" | docker login --username AWS --password-stdin \$ECR_REGISTRY || { echo "ECR login failed"; exit 1; }
              
              # Tag and push
              docker tag taskops:${env.IMAGE_LATEST} ${ECR_REPO}:${env.IMAGE_TAG} || { echo "Failed to tag image"; exit 1; }
              docker tag taskops:${env.IMAGE_LATEST} ${ECR_REPO}:${env.IMAGE_LATEST} || { echo "Failed to tag image"; exit 1; }
              docker push ${ECR_REPO}:${env.IMAGE_TAG} || { echo "Failed to push image"; exit 1; }
              docker push ${ECR_REPO}:${env.IMAGE_LATEST} || { echo "Failed to push image"; exit 1; }
              
              echo "Successfully pushed images to ECR"
            """
          }
        }
      }
    }

    stage('Configure EKS kubeconfig') {
      steps {
        script {
          echo 'Configuring kubectl for EKS cluster...'
          withCredentials([aws(credentialsId: 'aws-creds', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
            sh """
              # Export AWS credentials
              export AWS_ACCESS_KEY_ID=\${AWS_ACCESS_KEY_ID}
              export AWS_SECRET_ACCESS_KEY=\${AWS_SECRET_ACCESS_KEY}
              export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}
              
              # Find AWS CLI (same logic as ECR stage)
              AWS_CLI_PATH=""
              
              # First check if aws is in PATH and works
              if command -v aws > /dev/null 2>&1 && aws --version > /dev/null 2>&1; then
                AWS_CLI_PATH="aws"
              # Check common installation locations
              elif [ -f /usr/local/bin/aws ] && /usr/local/bin/aws --version > /dev/null 2>&1; then
                AWS_CLI_PATH="/usr/local/bin/aws"
                export PATH=/usr/local/bin:\$PATH
              elif [ -f /usr/local/aws/bin/aws ] && /usr/local/aws/bin/aws --version > /dev/null 2>&1; then
                AWS_CLI_PATH="/usr/local/aws/bin/aws"
                export PATH=/usr/local/aws/bin:\$PATH
              elif [ -f /var/lib/jenkins/.local/bin/aws ] && /var/lib/jenkins/.local/bin/aws --version > /dev/null 2>&1; then
                AWS_CLI_PATH="/var/lib/jenkins/.local/bin/aws"
                export PATH=/var/lib/jenkins/.local/bin:\$PATH
              else
                echo "AWS CLI not found. It should have been installed in the previous stage."
                echo "Please check the 'Login & Push to ECR' stage logs."
                exit 1
              fi
              
              echo "Using AWS CLI at: \$AWS_CLI_PATH"
              
              # Update kubeconfig with public endpoint access
              echo "Updating kubeconfig for EKS cluster..."
              \$AWS_CLI_PATH eks update-kubeconfig \
                --region ${AWS_DEFAULT_REGION} \
                --name ${EKS_CLUSTER_NAME} \
                --kubeconfig ${KUBECONFIG} || { echo "Failed to update kubeconfig"; exit 1; }
              
              # Verify kubectl can access cluster with retries
              echo "Verifying EKS cluster connection..."
              MAX_RETRIES=5
              RETRY_COUNT=0
              while [ \$RETRY_COUNT -lt \$MAX_RETRIES ]; do
                if kubectl --kubeconfig=${KUBECONFIG} get nodes --request-timeout=30s > /dev/null 2>&1; then
                  echo "Successfully connected to EKS cluster"
                  kubectl --kubeconfig=${KUBECONFIG} get nodes
                  break
                else
                  RETRY_COUNT=\$((RETRY_COUNT + 1))
                  echo "Connection attempt \$RETRY_COUNT/\$MAX_RETRIES failed. Retrying in 10 seconds..."
                  if [ \$RETRY_COUNT -lt \$MAX_RETRIES ]; then
                    sleep 10
                  else
                    echo "ERROR: Failed to connect to EKS cluster after \$MAX_RETRIES attempts"
                    echo "This might be due to:"
                    echo "1. Security group not allowing access from Jenkins"
                    echo "2. EKS cluster endpoint not accessible"
                    echo "3. Network connectivity issues"
                    echo "Please check the EKS cluster security group and ensure it allows traffic from Jenkins security group"
                    exit 1
                  fi
                fi
              done
              
              echo "Successfully configured kubeconfig for EKS cluster"
            """
          }
        }
      }
    }

    stage('Deploy to EKS') {
      steps {
        script {
          echo 'Deploying to EKS using Helm...'
          
          // Install/upgrade Helm chart with LoadBalancer for web access
          sh """
            helm upgrade --install taskops charts/taskops \
              --namespace taskops --create-namespace \
              --kubeconfig=${KUBECONFIG} \
              --set image.repository=${ECR_REPO} \
              --set image.tag=${env.IMAGE_LATEST} \
              --set service.type=LoadBalancer \
              --set service.port=8000 \
              --wait --timeout 5m || { echo "Helm deployment failed"; exit 1; }
          """
          
          // Get LoadBalancer URL
          sh """
            echo "Waiting for pods to be ready..."
            kubectl --kubeconfig=${KUBECONFIG} wait --namespace taskops \
              --for=condition=ready pod \
              --selector=app.kubernetes.io/name=taskops \
              --timeout=300s || { echo "Pods not ready"; exit 1; }
            
            echo "Getting LoadBalancer URL..."
            # Get service name (could be taskops-taskops or taskops depending on Helm naming)
            SERVICE_NAME=\$(kubectl --kubeconfig=${KUBECONFIG} get svc -n taskops -l app.kubernetes.io/name=taskops -o jsonpath='{.items[0].metadata.name}')
            
            if [ -z "\$SERVICE_NAME" ]; then
              echo "Service not found, trying default name..."
              SERVICE_NAME="taskops-taskops"
            fi
            
            echo "Service name: \$SERVICE_NAME"
            
            # Wait for LoadBalancer to get an external IP/hostname
            for i in {1..30}; do
              APP_URL=\$(kubectl --kubeconfig=${KUBECONFIG} get svc \$SERVICE_NAME -n taskops -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
              if [ -z "\$APP_URL" ]; then
                APP_URL=\$(kubectl --kubeconfig=${KUBECONFIG} get svc \$SERVICE_NAME -n taskops -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
              fi
              if [ -n "\$APP_URL" ]; then
                break
              fi
              echo "Waiting for LoadBalancer... (\$i/30)"
              sleep 10
            done
            
            if [ -z "\$APP_URL" ]; then
              echo "WARNING: LoadBalancer not ready yet. Service may still be provisioning."
              APP_URL="pending"
            fi
            
            echo "Application URL: http://\${APP_URL}:8000" > app-url.txt
            echo "Application deployed at: http://\${APP_URL}:8000"
          """
        }
      }
    }

    stage('Install Monitoring') {
      when {
        expression { params.INSTALL_MONITORING == true }
      }
      steps {
        script {
          echo 'Installing Prometheus/Grafana monitoring stack...'
          sh """
            helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || echo "Repo already exists"
            helm repo update || { echo "Failed to update helm repos"; exit 1; }
            helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
              --namespace monitoring --create-namespace \
              --kubeconfig=${KUBECONFIG} \
              --set prometheus.service.type=LoadBalancer \
              --set grafana.service.type=LoadBalancer \
              --set grafana.adminPassword=admin \
              --wait --timeout 10m || { echo "Failed to install monitoring stack"; exit 1; }
          """
          
          // Get Grafana URL
          sh """
            echo "Waiting for Grafana service to be ready..."
            sleep 30
            
            # Wait for Grafana LoadBalancer
            for i in {1..20}; do
              GRAFANA_URL=\$(kubectl --kubeconfig=${KUBECONFIG} get svc prometheus-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
              if [ -z "\$GRAFANA_URL" ]; then
                GRAFANA_URL=\$(kubectl --kubeconfig=${KUBECONFIG} get svc prometheus-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
              fi
              if [ -n "\$GRAFANA_URL" ]; then
                break
              fi
              echo "Waiting for Grafana LoadBalancer... (\$i/20)"
              sleep 10
            done
            
            if [ -z "\$GRAFANA_URL" ]; then
              echo "WARNING: Grafana LoadBalancer not ready yet"
              GRAFANA_URL="pending"
            fi
            
            echo "Grafana URL: http://\${GRAFANA_URL}" > grafana-url.txt
            echo "Grafana deployed at: http://\${GRAFANA_URL}"
            echo "Username: admin"
            echo "Password: admin"
          """
        }
      }
    }

    stage('Smoke Tests') {
      steps {
        script {
          echo 'Running smoke tests on EKS deployment...'
          sh """
            # Get service name
            SERVICE_NAME=\$(kubectl --kubeconfig=${KUBECONFIG} get svc -n taskops -l app.kubernetes.io/name=taskops -o jsonpath='{.items[0].metadata.name}')
            
            if [ -z "\$SERVICE_NAME" ]; then
              SERVICE_NAME="taskops-taskops"
            fi
            
            # Get LoadBalancer URL
            APP_URL=\$(kubectl --kubeconfig=${KUBECONFIG} get svc \$SERVICE_NAME -n taskops -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
            if [ -z "\$APP_URL" ]; then
              APP_URL=\$(kubectl --kubeconfig=${KUBECONFIG} get svc \$SERVICE_NAME -n taskops -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
            fi
            
            if [ -z "\$APP_URL" ] || [ "\$APP_URL" = "pending" ]; then
              echo "LoadBalancer not ready yet, using port-forward..."
              kubectl --kubeconfig=${KUBECONFIG} port-forward -n taskops svc/\$SERVICE_NAME 8000:8000 > /dev/null 2>&1 &
              PF_PID=\$!
              sleep 10
              
              echo "Testing health endpoint via port-forward..."
              curl -f http://localhost:8000/healthz || { echo "Health check failed"; kill \$PF_PID 2>/dev/null; exit 1; }
              
              echo "Testing metrics endpoint via port-forward..."
              curl -f http://localhost:8000/metrics | head -20 || { echo "Metrics check failed"; kill \$PF_PID 2>/dev/null; exit 1; }
              
              kill \$PF_PID 2>/dev/null || true
              echo "Smoke tests passed via port-forward"
            else
              echo "Testing application at: http://\${APP_URL}:8000"
              sleep 30  # Wait for LoadBalancer to be fully ready
              
              echo "Testing health endpoint..."
              curl -f http://\${APP_URL}:8000/healthz || { echo "Health check failed"; exit 1; }
              
              echo "Testing metrics endpoint..."
              curl -f http://\${APP_URL}:8000/metrics | head -20 || { echo "Metrics check failed"; exit 1; }
              
              echo "Smoke tests passed"
            fi
          """
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
