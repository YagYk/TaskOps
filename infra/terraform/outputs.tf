output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = module.eks.cluster_oidc_issuer_url
}

output "node_group_role_arn" {
  description = "IAM role ARN of the EKS managed node group"
  value       = module.eks.eks_managed_node_groups.main.iam_role_arn
}

output "ecr_repo_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.taskops.repository_url
}
