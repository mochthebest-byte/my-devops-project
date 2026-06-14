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

# Додаткова політика для ALB
data "aws_iam_policy_document" "lb_controller_extra" {
  statement {
    actions = [
      "ec2:*",
      "elasticloadbalancing:*",
      "iam:CreateServiceLinkedRole",
      "cognito-idp:DescribeUserPoolClient",
      "waf-regional:GetWebACL",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "lb_controller_extra" {
  name   = "${var.project_name}-lb-controller-extra"
  policy = data.aws_iam_policy_document.lb_controller_extra.json
}

resource "aws_iam_role_policy_attachment" "lb_controller_extra" {
  policy_arn = aws_iam_policy.lb_controller_extra.arn
  role       = aws_iam_role.lb_controller.name
}

# Встановлення LB Controller через Helm
resource "helm_release" "lb_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "~> 1.9"

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
    resources = ["*"]
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
  name       = "external-secrets"
  namespace  = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = "~> 0.14"

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

  depends_on = [helm_release.lb_controller]
}

# ══════════════════════════════════════════════════════════
#  ExternalDNS — створює DNS-записи в Route53
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
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets",
      "route53:ListHostedZones",
    ]
    resources = ["*"]
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
  version    = "~> 1.15"

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
