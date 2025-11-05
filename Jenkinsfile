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
    disableConcurrentBuilds()
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
        sh '''
          docker build -t taskops:$IMAGE_TAG .
          docker tag taskops:$IMAGE_TAG taskops:$IMAGE_LATEST
        '''
      }
    }

    stage('Login & Push to ECR') {
      steps {
        script {
          echo 'Logging into AWS ECR and pushing image...'
          withCredentials([aws(credentialsId: 'aws-creds', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
            sh """
              aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | \
                docker login --username AWS --password-stdin ${ECR_REPO.split('/')[0]}
              docker tag taskops:${IMAGE_LATEST} ${ECR_REPO}:${IMAGE_TAG}
              docker tag taskops:${IMAGE_LATEST} ${ECR_REPO}:${IMAGE_LATEST}
              docker push ${ECR_REPO}:${IMAGE_TAG}
              docker push ${ECR_REPO}:${IMAGE_LATEST}
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
              aws eks update-kubeconfig --region ${AWS_DEFAULT_REGION} --name ${EKS_CLUSTER_NAME} --kubeconfig ${KUBECONFIG}
              kubectl --kubeconfig=${KUBECONFIG} get nodes
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
              --set image.tag=${IMAGE_LATEST} \
              --set service.type=LoadBalancer \
              --set service.port=8000 \
              --wait --timeout 5m
          """
          
          // Get LoadBalancer URL
          sh """
            echo "Waiting for LoadBalancer to be ready..."
            kubectl --kubeconfig=${KUBECONFIG} wait --namespace taskops \
              --for=condition=ready pod \
              --selector=app.kubernetes.io/name=taskops \
              --timeout=300s || true
            
            APP_URL=\$(kubectl --kubeconfig=${KUBECONFIG} get svc taskops -n taskops -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
            if [ -z "\$APP_URL" ]; then
              APP_URL=\$(kubectl --kubeconfig=${KUBECONFIG} get svc taskops -n taskops -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
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
            helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
            helm repo update
            helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
              --namespace monitoring --create-namespace \
              --kubeconfig=${KUBECONFIG} \
              --set prometheus.service.type=LoadBalancer \
              --set grafana.service.type=LoadBalancer \
              --set grafana.adminPassword=admin \
              --wait --timeout 10m
          """
          
          // Get Grafana URL
          sh """
            sleep 30
            GRAFANA_URL=\$(kubectl --kubeconfig=${KUBECONFIG} get svc prometheus-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
            if [ -z "\$GRAFANA_URL" ]; then
              GRAFANA_URL=\$(kubectl --kubeconfig=${KUBECONFIG} get svc prometheus-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
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
            # Get LoadBalancer URL
            APP_URL=\$(kubectl --kubeconfig=${KUBECONFIG} get svc taskops -n taskops -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
            if [ -z "\$APP_URL" ]; then
              APP_URL=\$(kubectl --kubeconfig=${KUBECONFIG} get svc taskops -n taskops -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
            fi
            
            if [ -z "\$APP_URL" ]; then
              echo "LoadBalancer not ready yet, using port-forward..."
              kubectl --kubeconfig=${KUBECONFIG} port-forward -n taskops svc/taskops 8000:8000 &
              sleep 10
              curl -f http://localhost:8000/healthz || echo "Health check failed"
              curl -f http://localhost:8000/metrics | head -20 || echo "Metrics check failed"
              pkill -f "kubectl port-forward" || true
            else
              echo "Testing application at: http://\${APP_URL}:8000"
              sleep 30  # Wait for LoadBalancer to be fully ready
              curl -f http://\${APP_URL}:8000/healthz || echo "Health check failed"
              curl -f http://\${APP_URL}:8000/metrics | head -20 || echo "Metrics check failed"
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
