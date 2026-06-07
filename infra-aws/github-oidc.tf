# GitHub Actions OIDC - passwordless access to AWS
#
# Creates:
#   1. OIDC Identity Provider for token.actions.githubusercontent.com
#   2. IAM Role that GitHub Actions can assume via OIDC
#   3. Access policies: ECR push/pull + EKS describe
#   4. ECR repositories (my-app/vote, my-app/result, my-app/worker)
#   5. Lifecycle policies (auto-cleanup of old images)
#
# After terraform apply:
#   - Remove AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY from GitHub Secrets
#   - Use the github_ci_role_arn output in workflows
#
# Docs:
#   https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services

# 1. OIDC Identity Provider
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    # GitHub OIDC RSA key fingerprint
    "6938fd4d98bab03faadb97b34396831e3780aea1",
  ]

  tags = merge(var.tags, {
    Name = "github-actions-oidc"
  })
}

# 2. IAM Role + Trust Policy
#
# SUBJECT selection (token.actions.githubusercontent.com:sub)
#   Most secure (single repo): repo:mochthebest-byte/voting-app:*
#   Organization (all repos):   repo:mochthebest-byte/*:*
#   Widest (any repo):          repo:*:* (not recommended)
data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    # audience is always sts.amazonaws.com for AWS
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Scoped to specific org/repos
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [
        "repo:mochthebest-byte/voting-app:*",
        "repo:mochthebest-byte/result:*",
        "repo:mochthebest-byte/worker:*",
        "repo:mochthebest-byte/ci-pipelines:*",
        "repo:mochthebest-byte/my-devops-project:*",
      ]
    }
  }
}

# 3. Access Policies

# ECR: push/pull images
data "aws_iam_policy_document" "github_ci_ecr" {
  statement {
    sid = "ECRAuth"
    actions = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "ECRPushPull"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:ListImages",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:CreateRepository",
    ]
    resources = ["arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/my-app/*"]
  }
}

# EKS: read cluster state (for kubectl)
data "aws_iam_policy_document" "github_ci_eks" {
  statement {
    sid = "EKSDescribe"
    actions = ["eks:DescribeCluster"]
    resources = [
      "arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}",
    ]
  }
}

# Merged policy
resource "aws_iam_policy" "github_ci" {
  name        = "${var.cluster_name}-github-ci"
  description = "Permissions for GitHub Actions CI/CD"

  policy = data.aws_iam_policy_document.merged_ci_policy.json
  tags   = var.tags
}

data "aws_iam_policy_document" "merged_ci_policy" {
  source_policy_documents = [
    data.aws_iam_policy_document.github_ci_ecr.json,
    data.aws_iam_policy_document.github_ci_eks.json,
  ]
}

# 4. IAM Role
resource "aws_iam_role" "github_ci" {
  name               = "${var.cluster_name}-github-ci"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  # Max session duration: 1 hour
  max_session_duration = 3600

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-github-ci"
  })
}

resource "aws_iam_role_policy_attachment" "github_ci" {
  role       = aws_iam_role.github_ci.name
  policy_arn = aws_iam_policy.github_ci.arn
}

# 5. ECR Repositories
locals {
  ecr_repositories = [
    "my-app/vote",
    "my-app/result",
    "my-app/worker",
  ]
}

resource "aws_ecr_repository" "services" {
  for_each = toset(local.ecr_repositories)

  name                 = each.key
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}

# Lifecycle policy: keep last 10 images, expire untagged older than 90 days
resource "aws_ecr_lifecycle_policy" "cleanup" {
  for_each = aws_ecr_repository.services

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than 90 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 90
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 10 images (any tag)"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Outputs
output "github_ci_role_arn" {
  description = "ARN of the GitHub CI IAM Role. Use as ci_role_arn in workflows."
  value       = aws_iam_role.github_ci.arn
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC Identity Provider."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "ecr_repositories" {
  description = "Map of ECR repository names to ARN."
  value = {
    for k, r in aws_ecr_repository.services : k => r.repository_url
  }
}
