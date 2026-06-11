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
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeVpcs",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "elbv2:DescribeLoadBalancers",
      "elbv2:DescribeListeners",
      "elbv2:DescribeRules",
      "elbv2:CreateLoadBalancer",
      "elbv2:DeleteLoadBalancer",
      "elbv2:CreateListener",
      "elbv2:DeleteListener",
      "elbv2:CreateRule",
      "elbv2:DeleteRule",
      "elbv2:SetSecurityGroups",
      "elbv2:SetSubnets",
      "elbv2:CreateTargetGroup",
      "elbv2:DeleteTargetGroup",
      "elbv2:RegisterTargets",
      "elbv2:DeregisterTargets",
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
  addon_version = "v1.38.0-eksbuild.1"

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
