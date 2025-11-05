# Quick Start Guide - TaskOps CI/CD Pipeline

## 🚀 Step-by-Step Setup (15 minutes)

### Step 1: Get Jenkins Password (2 minutes)

1. Open PowerShell and run:
   ```powershell
   ssh -i C:\Users\Yagyansh's\.ssh\id_ed25519 ubuntu@13.127.103.123 'sudo cat /var/lib/jenkins/secrets/initialAdminPassword'
   ```
2. Copy the password that appears

### Step 2: Access Jenkins (1 minute)

1. Open browser: **http://13.127.103.123:8080**
2. Paste the password from Step 1
3. Click **Continue**

### Step 3: Install Jenkins Plugins (2 minutes)

1. Click **Install suggested plugins** (wait for installation)
2. Create Admin User:
   - **Username:** `admin` (or your choice)
   - **Password:** Choose a password
   - **Full name:** Your name
   - **Email:** Your email
3. Click **Save and Continue**
4. Click **Save and Finish**
5. Click **Start using Jenkins**

### Step 4: Configure AWS Credentials in Jenkins (3 minutes)

1. Go to **Manage Jenkins** → **Credentials** → **System** → **Global credentials (unrestricted)**
2. Click **Add Credentials** (or **Add** → **Add Credentials**)
3. Fill in:
   - **Kind:** `AWS Credentials`
   - **ID:** `aws-creds`
   - **Access Key ID:** `YOUR_AWS_ACCESS_KEY_ID` (Replace with your actual key)
   - **Secret Access Key:** `YOUR_AWS_SECRET_ACCESS_KEY` (Replace with your actual secret)
   - **Description:** `AWS Credentials for ECR and EKS`
4. Click **OK**

### Step 5: Install Required Plugins (2 minutes)

1. Go to **Manage Jenkins** → **Plugins**
2. Click **Available** tab
3. Search and install:
   - **Git Plugin** (if not installed)
   - **Pipeline Plugin** (if not installed)
   - **AWS Credentials Plugin** (if not installed)
   - **Kubernetes CLI Plugin** (if not installed)
4. Click **Install without restart** (or wait for restart)

### Step 6: Create Pipeline (3 minutes)

1. Click **New Item** on Jenkins dashboard
2. Enter name: `taskops-pipeline`
3. Select **Pipeline**
4. Click **OK**

5. Configure:
   - **Description:** `TaskOps CI/CD Pipeline - Git → Jenkins → EKS`
   
   - Scroll down to **Pipeline** section:
     - **Definition:** `Pipeline script from SCM`
     - **SCM:** `Git`
     - **Repository URL:** Your GitHub repository URL
       - Example: `https://github.com/yourusername/taskops.git`
     - **Credentials:** Leave empty (if public repo) or select GitHub credentials (if private)
     - **Branches to build:** `*/main` (or `*/master` if your main branch is master)
     - **Script Path:** `Jenkinsfile`
   
6. Click **Save**

### Step 7: Push Your Code to GitHub (2 minutes)

1. Open your terminal in the project folder:
   ```powershell
   cd "C:\Users\Yagyansh's\Documents\Devops Project"
   ```

2. If not already a git repository:
   ```powershell
   git init
   git add .
   git commit -m "Initial commit - TaskOps CI/CD"
   ```

3. Add GitHub remote (replace with your repo URL):
   ```powershell
   git remote add origin https://github.com/yourusername/taskops.git
   ```

4. Push to GitHub:
   ```powershell
   git branch -M main
   git push -u origin main
   ```

### Step 8: Trigger Pipeline (Auto or Manual)

#### Option A: Automatic (Recommended)
- Jenkins will automatically detect the push (polling every 2 minutes)
- Go to Jenkins dashboard and wait for the build to appear
- Or click **Build Now** to trigger immediately

#### Option B: Manual Trigger
1. Go to Jenkins dashboard
2. Click on `taskops-pipeline`
3. Click **Build Now**

### Step 9: Monitor Pipeline Execution (5-10 minutes)

1. Click on the build number (#1, #2, etc.)
2. Click **Console Output** to see real-time progress

**What happens:**
- ✅ Checks out code from Git
- ✅ Runs tests
- ✅ Builds Docker image
- ✅ Pushes to ECR
- ✅ Deploys to EKS
- ✅ Installs Grafana monitoring
- ✅ Runs smoke tests

### Step 10: Get Application URL (1 minute)

After pipeline completes successfully:

1. In the build console output, look for:
   ```
   Application deployed at: http://<IP>:8000
   ```

2. Or check the build artifacts:
   - Click on the build number
   - Click **Artifacts** or check console output for `app-url.txt`

3. **Access your application:**
   - Open: `http://<LOADBALANCER_IP>:8000`
   - You should see the TaskOps Todo application!

### Step 11: Access Grafana (1 minute)

1. In the build console output, look for:
   ```
   Grafana deployed at: http://<IP>
   Username: admin
   Password: admin
   ```

2. **Login to Grafana:**
   - Open: `http://<GRAFANA_IP>`
   - Username: `admin`
   - Password: `admin`

3. **View Dashboards:**
   - Go to **Dashboards** → **Browse**
   - You'll see pre-built Kubernetes monitoring dashboards

## 🎯 Continuous Deployment Flow

Once setup is complete, the workflow is **fully automatic**:

```
1. You make code changes
   ↓
2. You push to GitHub
   ↓
3. Jenkins detects the change (within 2 minutes)
   ↓
4. Jenkins automatically:
   - Builds the code
   - Runs tests
   - Creates Docker image
   - Pushes to ECR
   - Deploys to EKS
   - Updates monitoring
   ↓
5. Your application is live at LoadBalancer IP
   ↓
6. Monitor via Grafana
```

## 📝 Important Notes

### ✅ You DON'T need to:
- Manually build after logging into Jenkins
- Manually trigger builds (automatic on Git push)
- Manually deploy (automatic via pipeline)
- Manually update monitoring (automatic)

### ✅ You DO need to:
- Push code to GitHub to trigger pipeline
- Wait 5-10 minutes for first deployment
- Check Jenkins console for application URL

## 🔧 Troubleshooting

### Pipeline Fails at "Configure EKS kubeconfig"

**Solution:**
1. Check AWS credentials are correct in Jenkins
2. Verify EKS cluster exists:
   ```powershell
   aws eks describe-cluster --name taskops-k8s --region ap-south-1 --profile taskops
   ```

### Can't Access Application

**Solution:**
1. Wait 2-3 minutes for LoadBalancer to provision
2. Check Jenkins console output for LoadBalancer IP
3. Verify security group allows port 8000

### LoadBalancer IP Not Showing

**Solution:**
1. Wait longer (can take 5-10 minutes)
2. Check EKS service:
   ```powershell
   aws eks update-kubeconfig --region ap-south-1 --name taskops-k8s --profile taskops
   kubectl get svc taskops -n taskops
   ```

## 📞 Quick Commands

### Get Jenkins Password
```powershell
ssh -i C:\Users\Yagyansh's\.ssh\id_ed25519 ubuntu@13.127.103.123 'sudo cat /var/lib/jenkins/secrets/initialAdminPassword'
```

### Access Jenkins
```
http://13.127.103.123:8080
```

### Get EKS kubeconfig
```powershell
aws eks update-kubeconfig --region ap-south-1 --name taskops-k8s --profile taskops
```

### Check Application Service
```powershell
kubectl get svc taskops -n taskops
```

### Check Grafana Service
```powershell
kubectl get svc prometheus-grafana -n monitoring
```

## ✅ Checklist

- [ ] Jenkins password retrieved
- [ ] Jenkins accessed and configured
- [ ] AWS credentials added to Jenkins
- [ ] Required plugins installed
- [ ] Pipeline created from Git repository
- [ ] Code pushed to GitHub
- [ ] Pipeline triggered (manually or automatically)
- [ ] Application URL obtained from Jenkins console
- [ ] Application accessible via LoadBalancer IP
- [ ] Grafana accessible and monitoring working

## 🎉 Success!

Once all steps are complete:
- ✅ Your application is live at LoadBalancer IP
- ✅ Git push automatically triggers deployment
- ✅ Monitoring via Grafana is active
- ✅ Full CI/CD pipeline is operational

**You're all set!** Just push code to GitHub and watch it deploy automatically! 🚀

