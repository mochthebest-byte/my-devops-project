# ══════════════════════════════════════════════════════════
#  GitHub OIDC (Workload Identity Federation)
#  Безпарольна автентифікація GitHub Actions → AWS
#
#  ⚠️  Увімкнути через змінну create_github_oidc = true
#      Якщо ресурси вже створені вручну — використати
#      terraform import (див. коментарі нижче).
# ══════════════════════════════════════════════════════════

locals {
  github_oidc_url = "https://token.actions.githubusercontent.com"
}

# Отримуємо thumbprint GitHub OIDC сертифіката
data "tls_certificate" "github" {
  count = var.create_github_oidc ? 1 : 0
  url   = local.github_oidc_url
}

# ══════════════════════════════════════════════════════════
#  OIDC Identity Provider for GitHub Actions
# ══════════════════════════════════════════════════════════
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc ? 1 : 0

  url             = local.github_oidc_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github[0].certificates[0].sha1_fingerprint]

  tags = merge(var.tags, {
    Name = var.github_oidc_provider_name
  })
}

# ══════════════════════════════════════════════════════════
#  IAM Role для GitHub Actions CI
# ══════════════════════════════════════════════════════════
data "aws_iam_policy_document" "github_ci_assume_role" {
  count = var.create_github_oidc ? 1 : 0

  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github[0].arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        for repo in var.github_repo_allowlist :
        "repo:${repo}:*"
      ]
    }
  }
}

resource "aws_iam_role" "github_ci" {
  count = var.create_github_oidc ? 1 : 0

  name               = var.github_ci_role_name
  assume_role_policy = data.aws_iam_policy_document.github_ci_assume_role[0].json
  description        = "IAM role for GitHub Actions CI — OIDC (Workload Identity Federation)"
  max_session_duration = 3600

  tags = merge(var.tags, {
    Name = var.github_ci_role_name
  })
}

# ─── Політика для ECR push/pull ──────────────────────────
data "aws_iam_policy_document" "github_ci_permissions" {
  count = var.create_github_oidc ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "eks:DescribeCluster",
    ]
    resources = ["arn:aws:eks:${var.aws_region}:*:cluster/${var.project_name}-eks"]
  }
}

resource "aws_iam_policy" "github_ci_permissions" {
  count = var.create_github_oidc ? 1 : 0

  name        = "${var.project_name}-github-ci"
  description = "Permissions for GitHub Actions CI (ECR push + EKS describe)"
  policy      = data.aws_iam_policy_document.github_ci_permissions[0].json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "github_ci_permissions" {
  count = var.create_github_oidc ? 1 : 0

  role       = aws_iam_role.github_ci[0].name
  policy_arn = aws_iam_policy.github_ci_permissions[0].arn
}

# ══════════════════════════════════════════════════════════
#  Import (якщо ресурси вже створені вручну)
# ══════════════════════════════════════════════════════════
#
#  Розкоментувати після створення змінної create_github_oidc = true:
#
#  import {
#    to = aws_iam_openid_connect_provider.github[0]
#    id = "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
#  }
#
#  import {
#    to = aws_iam_role.github_ci[0]
#    id = "my-app-eks-github-ci"
#  }
#
#  Потім:
#    terraform plan   # має показати "No changes"
#    terraform apply
