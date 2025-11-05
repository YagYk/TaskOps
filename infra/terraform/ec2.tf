# EC2 Instance for Jenkins
resource "aws_instance" "jenkins" {
  ami                          = "ami-087d1c9a513324697" # Ubuntu 22.04 LTS (ap-south-1)
  instance_type                = "t3.large"  # Upgraded from t3.medium for better performance (2 vCPU, 8GB RAM)
  key_name                     = aws_key_pair.taskops_key.key_name
  subnet_id                    = module.vpc.public_subnets[0]
  associate_public_ip_address  = true
  vpc_security_group_ids       = [aws_security_group.jenkins.id]

  user_data = <<-EOF
    #!/bin/bash
    set -e
    
    # Update system
    apt-get update -y
    apt-get upgrade -y
    
    # Add swap space for better performance (4GB swap)
    fallocate -l 4G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
    
    # Optimize swappiness
    echo 'vm.swappiness=10' | tee -a /etc/sysctl.conf
    sysctl -p
    
    # Install Docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    
    # Configure Docker for better performance
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json <<DOCKER_EOF
    {
      "log-driver": "json-file",
      "log-opts": {
        "max-size": "10m",
        "max-file": "3"
      },
      "storage-driver": "overlay2"
    }
    DOCKER_EOF
    
    # Install Java 17 for Jenkins
    apt-get install -y openjdk-17-jdk
    
    # Install Jenkins
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
    echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | tee /etc/apt/sources.list.d/jenkins.list > /dev/null
    apt-get update -y
    apt-get install -y jenkins
    
    # Optimize Jenkins JVM memory settings (allocate 4GB heap for Jenkins)
    sed -i 's|JENKINS_JAVA_OPTIONS=.*|JENKINS_JAVA_OPTIONS="-Djava.awt.headless=true -Xmx4g -Xms2g -XX:+UseG1GC -XX:+UseStringDeduplication -XX:MaxMetaspaceSize=512m"|' /etc/default/jenkins
    
    # Add jenkins user to docker group
    usermod -aG docker jenkins
    
    # Install kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    
    # Install Helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    # Install Terraform
    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
    apt-get update && apt-get install -y terraform
    
    # Install AWS CLI
    curl "https://awscli.amazonaws.com/awscli-bundle.zip" -o "awscli-bundle.zip"
    apt-get install -y unzip
    unzip awscli-bundle.zip
    ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
    
    # Enable and restart Docker with optimized settings
    systemctl daemon-reload
    systemctl enable docker
    systemctl restart docker
    
    # Enable and start Jenkins with optimized settings
    systemctl enable jenkins
    systemctl start jenkins
    
    # Wait for Jenkins to start
    sleep 30
    
    # Get Jenkins initial password
    cat /var/lib/jenkins/secrets/initialAdminPassword > /home/ubuntu/jenkins-password.txt
    chown ubuntu:ubuntu /home/ubuntu/jenkins-password.txt
  EOF

  tags = {
    Name = "taskops-jenkins"
    Role = "jenkins"
  }
}

# EC2 Instance for Kubernetes Master (Control Plane)
resource "aws_instance" "k8s_master" {
  ami                          = "ami-087d1c9a513324697" # Ubuntu 22.04 LTS (ap-south-1)
  instance_type                = "t3.medium"
  key_name                     = aws_key_pair.taskops_key.key_name
  subnet_id                    = module.vpc.public_subnets[0]
  associate_public_ip_address   = true
  vpc_security_group_ids       = [aws_security_group.k8s.id]

  user_data = <<-EOF
    #!/bin/bash
    set -e
    
    # Update system
    apt-get update -y
    apt-get upgrade -y
    
    # Install Docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    
    # Install kubeadm, kubelet, kubectl
    apt-get install -y apt-transport-https ca-certificates curl gpg
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
    apt-get update -y
    apt-get install -y kubelet kubeadm kubectl
    apt-mark hold kubelet kubeadm kubectl
    
    # Configure Docker for Kubernetes
    cat > /etc/docker/daemon.json <<EOF2
    {
      "exec-opts": ["native.cgroupdriver=systemd"],
      "log-driver": "json-file",
      "log-opts": {
        "max-size": "100m"
      },
      "storage-driver": "overlay2"
    }
    EOF2
    
    systemctl daemon-reload
    systemctl restart docker
    systemctl enable kubelet
    
    # Install Helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  EOF

  tags = {
    Name = "taskops-k8s-master"
    Role = "kubernetes-master"
  }
}

# EC2 Instances for Kubernetes Workers
resource "aws_instance" "k8s_workers" {
  count                        = var.desired_size
  ami                          = "ami-087d1c9a513324697" # Ubuntu 22.04 LTS (ap-south-1)
  instance_type                = var.node_type
  key_name                     = aws_key_pair.taskops_key.key_name
  subnet_id                    = module.vpc.public_subnets[count.index % length(module.vpc.public_subnets)]
  associate_public_ip_address  = true
  vpc_security_group_ids       = [aws_security_group.k8s.id]

  user_data = <<-EOF
    #!/bin/bash
    set -e
    
    # Update system
    apt-get update -y
    apt-get upgrade -y
    
    # Install Docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    
    # Install kubeadm, kubelet, kubectl
    apt-get install -y apt-transport-https ca-certificates curl gpg
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
    apt-get update -y
    apt-get install -y kubelet kubeadm kubectl
    apt-mark hold kubelet kubeadm kubectl
    
    # Configure Docker
    cat > /etc/docker/daemon.json <<EOF2
    {
      "exec-opts": ["native.cgroupdriver=systemd"],
      "log-driver": "json-file",
      "log-opts": {
        "max-size": "100m"
      },
      "storage-driver": "overlay2"
    }
    EOF2
    
    systemctl daemon-reload
    systemctl restart docker
    systemctl enable kubelet
  EOF

  tags = {
    Name = "taskops-k8s-worker-${count.index + 1}"
    Role = "kubernetes-worker"
  }
}

# Security Group for Jenkins
resource "aws_security_group" "jenkins" {
  name        = "taskops-jenkins-sg"
  description = "Security group for Jenkins"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    description = "Jenkins"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "taskops-jenkins-sg"
  }
}

# Security Group for Kubernetes
resource "aws_security_group" "k8s" {
  name        = "taskops-k8s-sg"
  description = "Security group for Kubernetes cluster"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    description = "Kubernetes API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    description = "NodePort Services"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    description = "All traffic from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "taskops-k8s-sg"
  }
}

