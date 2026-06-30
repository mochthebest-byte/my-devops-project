# ══════════════════════════════════════════════════════════
#  VPC — публічні subnet (ALB) + приватні (EKS nodes)
# ══════════════════════════════════════════════════════════
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = [for i, az in var.azs : cidrsubnet(var.vpc_cidr, 8, i)]      # 10.0.0.0/24, 10.0.1.0/24
  public_subnets  = [for i, az in var.azs : cidrsubnet(var.vpc_cidr, 8, i + 10)] # 10.0.10.0/24, 10.0.11.0/24

  # NAT для приватних subnet (ноди отримують інтернет через NAT)
  enable_nat_gateway     = var.enable_nat_gateway
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = false
  enable_vpn_gateway     = false

  # Інтернет-гейтвей для публічних subnet (ALB)
  create_igw = true

  # Без публічних IP на нодах
  map_public_ip_on_launch = false

  # Теги для автоматичного виявлення субнетів ALB + EKS
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "karpenter.sh/discovery"          = "${var.project_name}-eks"
  }

  tags = var.tags
}

# ══════════════════════════════════════════════════════════
#  Security Group — наш власний модуль
# ══════════════════════════════════════════════════════════
module "app_sg" {
  source = "./modules/app-sg"

  vpc_id       = module.vpc.vpc_id
  vpc_cidr     = var.vpc_cidr
  project_name = var.project_name
  tags         = var.tags
}
