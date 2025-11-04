# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.30"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

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

