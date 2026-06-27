# ══════════════════════════════════════════════════════════
#  EKS Cluster — приватні ноди, без публічних IP
# ══════════════════════════════════════════════════════════
data "aws_iam_policy_document" "eks_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# ─── EKS Cluster + Managed Node Group ──────────────
# C15: використовуємо eks_managed_node_groups замість
#      standalone aws_eks_node_group.
#      IAM роль створює модуль (іменована voting-app-eks-ng).
#      Стара роль voting-app-eks-nodes буде видалена після apply.
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.project_name}-eks"
  cluster_version = var.eks_cluster_version

  # VPC + subnet
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.public_subnets

  # Публічний доступ до API — обмежено конкретним IP (C3 fix).
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.eks_public_access_cidrs
  cluster_endpoint_private_access      = true

  # Node Security Group
  node_security_group_id = module.app_sg.node_security_group_id

  # Access Entry для terraform-user
  access_entries = {
    terraform_user = {
      kubernetes_groups = []
      principal_arn     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/terraform-user"
      policy_associations = {
        admins = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  # ─── Managed Node Group (C15 fix) ──────────────
  # Заміняє standalone resource aws_eks_node_group
  eks_managed_node_groups = {
    main = {
      instance_types = var.eks_node_instance_types
      disk_size      = 20

      scaling_config = {
        desired_size = var.eks_desired_nodes
        min_size     = var.eks_min_nodes
        max_size     = var.eks_max_nodes
      }

      subnet_ids = module.vpc.private_subnets

      # Use existing IAM role to avoid recreating nodes
      create_iam_role          = false
      iam_role_arn             = aws_iam_role.nodes.arn
    }
  }

  tags = var.tags
}

# ─── IAM Role для Nodes (використовується eks_managed_node_groups) ──
resource "aws_iam_role" "nodes" {
  name = "${var.project_name}-eks-nodes"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "nodes_worker" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nodes.name
}

# ─── EBS CSI Driver (для PVC БД) ───────────────────
data "aws_iam_policy_document" "ebs_csi" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.project_name}-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi.name
}
