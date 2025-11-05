variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
  default     = "taskops-k8s"
}

variable "node_type" {
  description = "EC2 instance type for Kubernetes nodes"
  type        = string
  default     = "t3.medium"
}

variable "desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "key_name" {
  description = "Name of the AWS key pair"
  type        = string
}

variable "public_key_path" {
  description = "Path to the public key file"
  type        = string
}

variable "allowed_cidr" {
  description = "CIDR block allowed to access instances"
  type        = string
  default     = "0.0.0.0/0"
}
