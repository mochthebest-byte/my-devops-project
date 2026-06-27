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

variable "eks_public_access_cidrs" {
  description = "CIDRs allowed for EKS public API. Default VPC CIDR. Якщо потрібен доступ зовні — перевизначити через terraform.tfvars: [\"<ваш_IP>/32\"]"
  type        = list(string)
  default     = ["10.0.0.0/16"]
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
  default     = "mochthebest.pp.ua"
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

# ══════════════════════════════════════════════════════════
#  GitHub OIDC (WIF) — опційно
# ══════════════════════════════════════════════════════════
variable "create_github_oidc" {
  description = "Створити GitHub OIDC provider + IAM role для CI (WIF без статичних ключів)"
  type        = bool
  default     = false
}

variable "github_ci_role_name" {
  description = "Назва IAM ролі для GitHub Actions CI"
  type        = string
  default     = "my-app-eks-github-ci"
}

variable "github_repo_allowlist" {
  description = "Список GitHub репозиторіїв, які можуть асумувати CI роль"
  type        = list(string)
  default     = ["mochthebest-byte/my-devops-project", "mochthebest-byte/voting-app"]
}

variable "github_oidc_provider_name" {
  description = "Назва OIDC provider для GitHub Actions"
  type        = string
  default     = "github-oidc"
}

variable "tags" {
  description = "Tags for all resources"
  type        = map(string)
  default = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
