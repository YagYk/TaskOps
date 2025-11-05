# TaskOps CI/CD Deployment Guide

This guide walks you through setting up and using the complete CI/CD pipeline for TaskOps.

## Architecture Overview

```
GitHub Repository
      ↓ (Push triggers)
Jenkins (on EC2)
      ↓ (Builds & Tests)
Docker Image → ECR
      ↓ (Deploys)
EKS Cluster
      ↓ (Service)
LoadBalancer (Public IP)
      ↓
TaskOps Application (http://<LOADBALANCER_IP>:8000)
```

## Prerequisites

1. **AWS Account** with:
   - EKS cluster created (already done via Terraform)
   - ECR repository created (already done)
   - IAM credentials with necessary permissions

2. **Jenkins Instance** (already created at `13.127.103.123`)

3. **GitHub Repository** with this code

## Step-by-Step Setup

### Step 1: Access Jenkins

1. **Get Jenkins Initial Password:**
   ```bash
   ssh -i C:\Users\Yagyansh's\.ssh\id_ed25519 ubuntu@13.127.103.123 'sudo cat /var/lib/jenkins/secrets/initialAdminPassword'
   ```

2. **Open Jenkins:**
   - Go to: http://13.127.103.123:8080
   - Enter the password from step 1

3. **Install Recommended Plugins** (when prompted)

4. **Create Admin User** (or skip if you want to use the default)

### Step 2: Configure Jenkins Credentials

#### A. AWS Credentials

1. Go to **Manage Jenkins** → **Credentials** → **System** → **Global credentials**
2. Click **Add Credentials**
3. Fill in:
   - **Kind:** AWS Credentials
   - **ID:** `aws-creds`
   - **Access Key ID:** `YOUR_AWS_ACCESS_KEY_ID` (Replace with your actual key)
   - **Secret Access Key:** `YOUR_AWS_SECRET_ACCESS_KEY` (Replace with your actual secret)
   - **Description:** AWS Credentials for ECR and EKS
4. Click **OK**

#### B. GitHub Credentials (if using private repo)

1. Go to **Manage Jenkins** → **Credentials** → **System** → **Global credentials**
2. Click **Add Credentials**
3. Fill in:
   - **Kind:** Username with password
   - **ID:** `github-creds`
   - **Username:** Your GitHub username
   - **Password:** Your GitHub Personal Access Token
4. Click **OK**

### Step 3: Install Required Jenkins Plugins

1. Go to **Manage Jenkins** → **Plugins**
2. Install (if not already installed):
   - **Git Plugin**
   - **Pipeline Plugin**
   - **AWS Credentials Plugin**
   - **Kubernetes CLI Plugin**
   - **Helm Plugin**

### Step 4: Create Jenkins Pipeline

1. Click **New Item** on Jenkins dashboard
2. Enter name: `taskops-pipeline`
3. Select **Pipeline**
4. Click **OK**

5. **Configure the Pipeline:**

   - **Description:** `TaskOps CI/CD Pipeline - Git → Jenkins → EKS`
   
   - **Pipeline Definition:**
     - **Definition:** Pipeline script from SCM
     - **SCM:** Git
     - **Repository URL:** Your GitHub repository URL (e.g., `https://github.com/yourusername/taskops.git`)
     - **Credentials:** Select `github-creds` (if private repo) or leave empty (if public)
     - **Branches to build:** `*/main` or `*/master`
     - **Script Path:** `Jenkinsfile`
     - **Lightweight checkout:** Unchecked (we need full checkout)

6. Click **Save**

### Step 5: Configure Git Webhook (Optional but Recommended)

#### Option A: GitHub Webhook (Recommended)

1. Go to your GitHub repository
2. Go to **Settings** → **Webhooks** → **Add webhook**
3. Fill in:
   - **Payload URL:** `http://13.127.103.123:8080/github-webhook/`
   - **Content type:** `application/json`
   - **Events:** Just the `push` event
4. Click **Add webhook**

#### Option B: Polling (Already Configured)

The Jenkinsfile already has polling configured to check for changes every 2 minutes. This works without webhooks.

### Step 6: First Pipeline Run

**You don't need to manually build after logging in!** The pipeline will automatically:

1. **Trigger on Git Push:** When you push code to GitHub, Jenkins will automatically detect it (via webhook or polling)
2. **Or Trigger Manually:** Click **Build Now** on the pipeline page

### Step 7: Monitor Pipeline Execution

1. Click on your pipeline name (`taskops-pipeline`)
2. Click on the build number (#1, #2, etc.)
3. Click **Console Output** to see real-time logs

The pipeline will:
- ✅ Checkout code from Git
- ✅ Run tests
- ✅ Build Docker image
- ✅ Push to ECR
- ✅ Deploy to EKS
- ✅ Install monitoring (Prometheus/Grafana)
- ✅ Run smoke tests

### Step 8: Access Your Application

After the pipeline completes successfully:

1. **Get Application URL:**
   - Check the Jenkins console output for: `Application deployed at: http://<IP>:8000`
   - Or check the build artifacts: `app-url.txt`

2. **Access the Application:**
   - Open: `http://<LOADBALANCER_IP>:8000`
   - You should see the TaskOps Todo application

3. **Verify it's working:**
   ```bash
   curl http://<LOADBALANCER_IP>:8000/healthz
   # Should return: {"status":"ok"}
   ```

### Step 9: Access Grafana Monitoring

1. **Get Grafana URL:**
   - Check Jenkins console output for: `Grafana deployed at: http://<IP>`
   - Or check build artifacts: `grafana-url.txt`

2. **Login to Grafana:**
   - URL: `http://<GRAFANA_IP>`
   - Username: `admin`
   - Password: `admin`

3. **View Dashboards:**
   - Go to **Dashboards** → **Browse**
   - You'll see pre-built dashboards for:
     - Kubernetes / Compute Resources / Cluster
     - Kubernetes / Compute Resources / Pod
     - Node Exporter Full

## Continuous Deployment Flow

Once setup is complete, the workflow is automatic:

```
1. Developer pushes code to GitHub
   ↓
2. Jenkins detects change (webhook/polling)
   ↓
3. Jenkins automatically:
   - Checks out code
   - Runs tests
   - Builds Docker image
   - Pushes to ECR
   - Deploys to EKS
   - Installs/updates monitoring
   - Runs smoke tests
   ↓
4. Application is live at LoadBalancer IP
   ↓
5. Monitor via Grafana
```

## Manual Pipeline Trigger

If you want to manually trigger a build:

1. Go to Jenkins dashboard
2. Click on `taskops-pipeline`
3. Click **Build with Parameters**
4. Select:
   - **DEPLOY_TARGET:** `eks`
   - **INSTALL_MONITORING:** `true` (checked)
5. Click **Build**

## Troubleshooting

### Pipeline Fails at "Configure EKS kubeconfig"

**Issue:** Jenkins can't connect to EKS cluster

**Solution:**
1. Verify AWS credentials are correct in Jenkins
2. Check if EKS cluster is running:
   ```bash
   aws eks describe-cluster --name taskops-k8s --region ap-south-1 --profile taskops
   ```
3. Ensure Jenkins has `kubectl` and `aws` CLI installed:
   ```bash
   ssh -i C:\Users\Yagyansh's\.ssh\id_ed25519 ubuntu@13.127.103.123
   kubectl version --client
   aws --version
   ```

### LoadBalancer Not Getting IP

**Issue:** Application URL shows as empty

**Solution:**
1. Wait 2-3 minutes for LoadBalancer to provision
2. Check service status:
   ```bash
   kubectl get svc taskops -n taskops
   ```
3. If still pending, check AWS console for LoadBalancer creation

### Can't Access Application via IP

**Issue:** Browser shows connection refused

**Solution:**
1. Verify LoadBalancer is ready:
   ```bash
   kubectl get svc taskops -n taskops
   ```
2. Check security group allows port 8000
3. Wait for DNS propagation (can take a few minutes)

### Grafana Not Accessible

**Issue:** Can't access Grafana dashboard

**Solution:**
1. Check if Grafana service is running:
   ```bash
   kubectl get svc prometheus-grafana -n monitoring
   ```
2. Wait for LoadBalancer to be provisioned
3. Check Jenkins console output for Grafana URL

## Useful Commands

### Check EKS Cluster Status
```bash
aws eks describe-cluster --name taskops-k8s --region ap-south-1 --profile taskops
```

### Get Application URL
```bash
kubectl get svc taskops -n taskops -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### Get Grafana URL
```bash
kubectl get svc prometheus-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### View Pods
```bash
kubectl get pods -n taskops
```

### View All Services
```bash
kubectl get svc --all-namespaces
```

## Next Steps

1. ✅ Push code to GitHub
2. ✅ Jenkins will automatically build and deploy
3. ✅ Access application at LoadBalancer IP
4. ✅ Monitor via Grafana
5. ✅ Make changes and push - automatic deployment!

## Summary

- **No manual build needed** - Pipeline triggers automatically on Git push
- **Application accessible** via LoadBalancer IP (from Jenkins console output)
- **Monitoring** via Grafana at the LoadBalancer IP (from Jenkins console output)
- **Full CI/CD** - Git → Jenkins → ECR → EKS → Live Application

