# ══════════════════════════════════════════════════════════
#  AWS Load Balancer Controller — створює ALB/NLB
# ══════════════════════════════════════════════════════════
data "aws_iam_policy_document" "lb_controller" {
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
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "lb_controller" {
  name               = "${var.project_name}-lb-controller"
  assume_role_policy = data.aws_iam_policy_document.lb_controller.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
  role       = aws_iam_role.lb_controller.name
}

# Додаткова політика для ALB (scoped — iam_policy.json)
#
# Замість широких ec2:* + elasticloadbalancing:* на * використовуємо
# гранулярну політику з умовами на теґ elbv2.k8s.aws/cluster.
resource "aws_iam_policy" "lb_controller_scoped" {
  name   = "${var.project_name}-lb-controller-scoped"
  policy = file("${path.module}/iam_policy.json")
}

resource "aws_iam_role_policy_attachment" "lb_controller_scoped" {
  policy_arn = aws_iam_policy.lb_controller_scoped.arn
  role       = aws_iam_role.lb_controller.name
}

# Встановлення LB Controller через Helm
resource "helm_release" "lb_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "~> 3.4"

  values = [file("${path.module}/lb-values.yaml")]

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.lb_controller.arn
  }
  set {
    name  = "region"
    value = var.aws_region
  }
  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }
  set {
    name  = "defaultTargetType"
    value = "ip"
  }

  depends_on = [aws_eks_addon.vpc_cni]
}

# ══════════════════════════════════════════════════════════
#  EKS Addons
# ══════════════════════════════════════════════════════════
resource "aws_eks_addon" "ebs_csi" {
  cluster_name  = module.eks.cluster_name
  addon_name    = "aws-ebs-csi-driver"
  addon_version = "v1.61.1-eksbuild.1"

  service_account_role_arn = aws_iam_role.ebs_csi.arn
}

resource "aws_eks_addon" "coredns" {
  cluster_name = module.eks.cluster_name
  addon_name   = "coredns"
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = module.eks.cluster_name
  addon_name   = "kube-proxy"
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = module.eks.cluster_name
  addon_name   = "vpc-cni"
}

# ══════════════════════════════════════════════════════════
#  External Secrets Operator — синхронізує секрети з AWS SM
# ══════════════════════════════════════════════════════════
data "aws_iam_policy_document" "eso" {
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
      values   = ["system:serviceaccount:external-secrets:external-secrets"]
    }
  }
}

data "aws_iam_policy_document" "eso_secrets" {
  statement {
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    # Обмежено до проєктних секретів — /my-app/* та його варіації
    resources = ["arn:aws:secretsmanager:*:*:secret:/my-app/*"]
  }
}

resource "aws_iam_role" "eso" {
  name               = "${var.project_name}-eks-eso"
  assume_role_policy = data.aws_iam_policy_document.eso.json
  tags               = var.tags
}

resource "aws_iam_policy" "eso_secrets" {
  name   = "${var.project_name}-eso-secrets"
  policy = data.aws_iam_policy_document.eso_secrets.json
}

resource "aws_iam_role_policy_attachment" "eso_secrets" {
  policy_arn = aws_iam_policy.eso_secrets.arn
  role       = aws_iam_role.eso.name
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "~> 0.14"

  set {
    name  = "installCRDs"
    value = "true"
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "external-secrets"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.eso.arn
  }

  depends_on = [helm_release.lb_controller, module.eks]
}

# ══════════════════════════════════════════════════════════
#  ExternalDNS — створює DNS-записи в Route53
#
#  ⚠️  Залежить від LB Controller webhook, який готовий
#      тільки після того, як ноди запустились.
# ══════════════════════════════════════════════════════════
data "aws_iam_policy_document" "external_dns" {
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
      values   = ["system:serviceaccount:kube-system:external-dns"]
    }
  }
}

data "aws_iam_policy_document" "external_dns_route53" {
  statement {
    actions = [
      "route53:ListHostedZones",
    ]
    resources = ["*"]
  }
  statement {
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets",
    ]
    resources = [aws_route53_zone.main.arn]
  }
}

resource "aws_iam_role" "external_dns" {
  name               = "${var.project_name}-eks-external-dns"
  assume_role_policy = data.aws_iam_policy_document.external_dns.json
  tags               = var.tags
}

resource "aws_iam_policy" "external_dns_route53" {
  name   = "${var.project_name}-external-dns-route53"
  policy = data.aws_iam_policy_document.external_dns_route53.json
}

resource "aws_iam_role_policy_attachment" "external_dns_route53" {
  policy_arn = aws_iam_policy.external_dns_route53.arn
  role       = aws_iam_role.external_dns.name
}

resource "helm_release" "external_dns" {
  name       = "external-dns"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/external-dns"
  chart      = "external-dns"
  version    = "~> 1.21"

  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "external-dns"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.external_dns.arn
  }
  set {
    name  = "service.enabled"
    value = "false"
  }
  set {
    name  = "aws.region"
    value = var.aws_region
  }
  set {
    name  = "domainFilters[0]"
    value = var.domain_name
  }
  set {
    name  = "policy"
    value = "sync"
  }
  set {
    name  = "txtOwnerId"
    value = "voting-app-eks"
  }

  depends_on = [helm_release.lb_controller]
}

# ══════════════════════════════════════════════════════════
#  ArgoCD Image Updater — автоматичне оновлення образів
# ══════════════════════════════════════════════════════════
data "aws_iam_policy_document" "argocd_image_updater" {
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
      values   = ["system:serviceaccount:argocd:argocd-image-updater"]
    }
  }
}

data "aws_iam_policy_document" "argocd_image_updater_ecr" {
  statement {
    actions = [
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:BatchGetImage",
      "ecr:GetRepositoryPolicy",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability",
    ]
    resources = ["arn:aws:ecr:*:*:repository/my-app/*"]
  }
}

resource "aws_iam_role" "argocd_image_updater" {
  name               = "${var.project_name}-eks-argocd-image-updater"
  assume_role_policy = data.aws_iam_policy_document.argocd_image_updater.json
  tags               = var.tags
}

resource "aws_iam_policy" "argocd_image_updater_ecr" {
  name   = "${var.project_name}-argocd-image-updater-ecr"
  policy = data.aws_iam_policy_document.argocd_image_updater_ecr.json
}

resource "aws_iam_role_policy_attachment" "argocd_image_updater_ecr" {
  policy_arn = aws_iam_policy.argocd_image_updater_ecr.arn
  role       = aws_iam_role.argocd_image_updater.name
}

# ══════════════════════════════════════════════════════════
#  Karpenter — автоматичне масштабування нод (EC2 Spot/On-Demand)
# ══════════════════════════════════════════════════════════

# ─── Karpenter Node IAM Role ──────────────────────────
resource "aws_iam_role" "karpenter_node" {
  name = "${var.project_name}-karpenter-node"

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

resource "aws_iam_role_policy_attachment" "karpenter_node_worker" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.karpenter_node.name
}

resource "aws_iam_role_policy_attachment" "karpenter_node_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.karpenter_node.name
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.karpenter_node.name
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.karpenter_node.name
}

# ─── Karpenter Node Instance Profile ──────────────────
resource "aws_iam_instance_profile" "karpenter_node" {
  name = "${var.project_name}-karpenter-node"
  role = aws_iam_role.karpenter_node.name
}

# ─── Karpenter Controller IAM Role (IRSA) ─────────────
data "aws_iam_policy_document" "karpenter_controller_assume" {
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
      values   = ["system:serviceaccount:karpenter:karpenter"]
    }
  }
}

resource "aws_iam_role" "karpenter_controller" {
  name               = "${var.project_name}-karpenter-controller"
  assume_role_policy = data.aws_iam_policy_document.karpenter_controller_assume.json
  tags               = var.tags
}

# ─── Karpenter Controller IAM Policy ──────────────────
data "aws_iam_policy_document" "karpenter_controller" {
  statement {
    actions = [
      "ec2:CreateLaunchTemplate",
      "ec2:CreateFleet",
      "ec2:RunInstances",
      "ec2:CreateTags",
      "ec2:TerminateInstances",
      "ec2:DescribeLaunchTemplates",
      "ec2:DeleteLaunchTemplate",
      "ec2:DescribeInstances",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeSubnets",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeVpcPeeringConnections",
      "ec2:DescribeVpcs",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:DetachNetworkInterface",
      "ec2:DescribeNetworkInterfaceAttribute",
      "ec2:ModifyNetworkInterfaceAttribute",
      "ec2:DescribeKeyPairs",
      "ec2:DescribeSecurityGroupRules",
      "ec2:DescribePrefixLists",
      "ec2:DescribeRegions",
      "iam:PassRole",
      "pricing:GetProducts",
      "ssm:GetParameter",
    ]
    resources = ["*"]
  }
  statement {
    actions = [
      "eks:DescribeCluster",
    ]
    resources = ["arn:aws:eks:*:*:cluster/${var.project_name}-eks"]
  }
  statement {
    actions = [
      "iam:CreateInstanceProfile",
      "iam:TagInstanceProfile",
      "iam:GetInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
    ]
    resources = ["arn:aws:iam::*:instance-profile/${var.project_name}-karpenter-*"]
  }
  statement {
    actions = [
      "iam:GetRole",
      "iam:PassRole",
    ]
    resources = ["arn:aws:iam::*:role/${var.project_name}-karpenter-*"]
  }
}

resource "aws_iam_policy" "karpenter_controller" {
  name   = "${var.project_name}-karpenter-controller"
  policy = data.aws_iam_policy_document.karpenter_controller.json
}

resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  policy_arn = aws_iam_policy.karpenter_controller.arn
  role       = aws_iam_role.karpenter_controller.name
}


