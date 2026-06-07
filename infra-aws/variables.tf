variable "aws_region" {
  description = "AWS region to deploy all resources into."
  type        = string
  default     = "us-east-1"
}

variable "vpc_name" {
  description = "Name tag for the VPC."
  type        = string
  default     = "my-app-vpc"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of Availability Zones to spread subnets across."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets (one per AZ)."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets (one per AZ)."
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

# ── EKS ──

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
  default     = "my-app-eks"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.30"
}

variable "node_instance_types" {
  description = "EC2 instance types for the EKS managed node group."
  type        = list(string)
  default     = ["t3.small", "t3.medium", "t2.medium"]
}

variable "node_desired_size" {
  description = "Desired number of worker nodes."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 5
}

# ── Tags ──

# ── GitHub OIDC CI/CD ──

variable "create_aws_auth_ci_mapping" {
  description = "Whether to add the GitHub CI role to the EKS aws-auth ConfigMap."
  type        = bool
  default     = false
  # ⚠️  УВАГА: увімкніть лише якщо CI виконує kubectl напряму.
  #    При використанні ArgoCD залиште false — CI лише оновлює GitOps-репо.
}

variable "github_ci_k8s_groups" {
  description = "Kubernetes RBAG groups for the GitHub CI role in aws-auth."
  type        = list(string)
  default     = ["eks-console-dashboard-cluster-reader"]
}

variable "tags" {
  description = "Map of tags to apply to all resources."
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "my-app"
    ManagedBy   = "terraform"
  }
}
