variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "voting-app"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability Zones"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b"]
}

variable "eks_cluster_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.31"
}

variable "eks_node_instance_types" {
  description = "EC2 instance types for EKS nodes"
  type        = list(string)
  default     = ["t3.small", "t3.medium"]
}

variable "eks_desired_nodes" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
}

variable "eks_min_nodes" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "eks_max_nodes" {
  description = "Maximum number of nodes"
  type        = number
  default     = 4
}

variable "domain_name" {
  description = "Domain name for Route53 zone"
  type        = string
  default     = "mochthebest.io"
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway to reduce cost"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags for all resources"
  type        = map(string)
  default = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
