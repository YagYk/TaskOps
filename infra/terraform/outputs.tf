# Jenkins outputs
output "jenkins_public_ip" {
  description = "Public IP of Jenkins instance"
  value       = aws_instance.jenkins.public_ip
}

output "jenkins_url" {
  description = "Jenkins URL"
  value       = "http://${aws_instance.jenkins.public_ip}:8080"
}

output "jenkins_initial_password" {
  description = "Jenkins initial admin password (stored on server)"
  value       = "Run: ssh -i ${replace(var.public_key_path, ".pub", "")} ubuntu@${aws_instance.jenkins.public_ip} 'sudo cat /var/lib/jenkins/secrets/initialAdminPassword'"
}

# Kubernetes outputs
output "k8s_master_public_ip" {
  description = "Public IP of Kubernetes master"
  value       = aws_instance.k8s_master.public_ip
}

output "k8s_worker_ips" {
  description = "Public IPs of Kubernetes workers"
  value       = aws_instance.k8s_workers[*].public_ip
}

output "ssh_to_jenkins" {
  description = "SSH command to Jenkins"
  value       = "ssh -i ${replace(var.public_key_path, ".pub", "")} ubuntu@${aws_instance.jenkins.public_ip}"
}

output "ssh_to_k8s_master" {
  description = "SSH command to K8s master"
  value       = "ssh -i ${replace(var.public_key_path, ".pub", "")} ubuntu@${aws_instance.k8s_master.public_ip}"
}

# ECR output
output "ecr_repo_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.taskops.repository_url
}

# EKS outputs
output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_kubeconfig_command" {
  description = "Command to update kubeconfig for EKS cluster"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name} --profile taskops"
}

output "eks_cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "jenkins_security_group_id" {
  description = "Security group ID attached to Jenkins instance"
  value       = aws_security_group.jenkins.id
}
