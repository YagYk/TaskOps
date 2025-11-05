#!/bin/bash
set -e

# Setup Kubernetes Master
if [[ "$(hostname)" == *"master"* ]]; then
  echo "Setting up Kubernetes Master..."
  
  # Get private IP
  MASTER_IP=$(hostname -I | awk '{print $1}')
  
  # Initialize cluster
  kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$MASTER_IP
  
  # Setup kubeconfig
  mkdir -p $HOME/.kube
  cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  chown $(id -u):$(id -g) $HOME/.kube/config
  
  # Install Flannel CNI
  kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
  
  # Wait for CNI to be ready
  sleep 30
  
  # Get join command
  kubeadm token create --print-join-command > /home/ubuntu/join-command.sh
  chmod +x /home/ubuntu/join-command.sh
  chown ubuntu:ubuntu /home/ubuntu/join-command.sh
  
  # Make kubeconfig accessible
  cp /etc/kubernetes/admin.conf /home/ubuntu/kubeconfig
  chown ubuntu:ubuntu /home/ubuntu/kubeconfig
  
  echo "Master setup complete!"
  echo "Join command saved to: /home/ubuntu/join-command.sh"
  echo "kubeconfig saved to: /home/ubuntu/kubeconfig"
fi

# Setup Kubernetes Worker
if [[ "$(hostname)" == *"worker"* ]]; then
  echo "Setting up Kubernetes Worker..."
  echo "Worker ready. Run join command from master to join this node to the cluster."
  echo "To get join command, SSH to master and run: cat /home/ubuntu/join-command.sh"
fi

