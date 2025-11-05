# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.30"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true
  cluster_endpoint_private_access = true
  
  # Allow public access from anywhere (you can restrict this to specific IPs)
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
  
  # Allow private access from VPC
  cluster_endpoint_private_access_cidrs = [module.vpc.vpc_cidr_block]

  # EKS Managed Node Group
  eks_managed_node_groups = {
    main = {
      min_size     = 1
      max_size     = 3
      desired_size = var.desired_size

      instance_types = [var.node_type]

      labels = {
        Environment = "dev"
        Application = "taskops"
      }
    }
  }

  tags = {
    Environment = "dev"
    Application = "taskops"
  }
}

# Security group rule to allow Jenkins to access EKS endpoint
resource "aws_security_group_rule" "eks_endpoint_from_jenkins" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.jenkins.id
  security_group_id        = module.eks.cluster_security_group_id
  description              = "Allow Jenkins to access EKS cluster endpoint"
}

