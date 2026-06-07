# ─────────────────────────────────────────────────────────
# GitHub Actions OIDC — безпарольний доступ до AWS
# ─────────────────────────────────────────────────────────
# Цей файл створює:
#   1. OIDC Identity Provider для token.actions.githubusercontent.com
#   2. IAM Role, яку GitHub Actions може assume через OIDC
#   3. Політики доступу до ECR та EKS
#
# Після apply можна видалити AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
# з GitHub Secrets — жодних статичних ключів більше не потрібно.
# ─────────────────────────────────────────────────────────

# ── 1. OIDC Identity Provider для GitHub Actions ──────
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    # Офіційний thumbprint GitHub OIDC (RSA 2048 SHA-1)
    "6938fd4d98bab03faadb97b34396831e3780aea1",
  ]
  # ⚠️ Якщо AWS відхиляє thumbprint, згенеруйте свіжий:
  #   openssl s_client -servername token.actions.githubusercontent.com \
  #     -connect token.actions.githubusercontent.com:443 2>&- </dev/null \
  #     | openssl x509 -fingerprint -noout -sha1 \
  #     | cut -d= -f2

  tags = merge(var.tags, {
    Name        = "github-actions-oidc"
    Description = "GitHub Actions OIDC provider"
  })
}

# ── 2. IAM Role для CI/CD (GitHub Actions → AWS) ─────
#
# ╔══════════════════════════════════════════════════════╗
# ║  ВИБІР РІВНЯ ДОСТУПУ                                 ║
# ║                                                       ║
# ║  Варіант А — один репозиторій (найбезпечніше):        ║
# ║    repo:my-org/voting-app:*                            ║
# ║                                                       ║
# ║  Варіант Б — всі репо організації:                    ║
# ║    repo:my-org/*:*                                    ║
# ║                                                       ║
# ║  Варіант В — всі репо + всі гілки (найширше):         ║
# ║    repo:*:*                                           ║
# ╚══════════════════════════════════════════════════════╝

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # ═══ ЗМІНІТЬ НА ВАШЕ ЗНАЧЕННЯ ═══
    # Варіант А: конкретний репозиторій
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:my-org/*:*"]
    }
  }
}

# ── 3. Політика доступу до ECR ────────────────────────
data "aws_iam_policy_document" "github_ci_ecr" {
  statement {
    sid = "ECRAuth"
    actions = [
      "ecr:GetAuthorizationToken",
    ]
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
    resources = ["arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/*"]
  }
}

# ── 4. Політика доступу до EKS ────────────────────────
data "aws_iam_policy_document" "github_ci_eks" {
  statement {
    sid = "EKSDescribe"
    actions = [
      "eks:DescribeCluster",
    ]
    resources = [
      "arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}",
    ]
  }

  # Для eks:UpdateKubeconfig на стороні GitHub Runner не потрібен,
  # але для kubectl apply/delete потрібен доступ через aws-auth.
  # Додаємо eks:DescribeCluster — це єдине, що потрібно на рівні IAM,
  # решта (k8s RBAC) контролюється через aws-auth ConfigMap.
}

# ── 5. Загальна CI/CD політика (ECR + EKS) ────────────
resource "aws_iam_policy" "github_ci" {
  name        = "${var.cluster_name}-github-ci"
  description = "Permissions for GitHub Actions CI/CD: ECR push/pull + EKS describe"
  policy = data.aws_iam_policy_document.merged_ci_policy.json
  tags  = var.tags
}

data "aws_iam_policy_document" "merged_ci_policy" {
  source_policy_documents = [
    data.aws_iam_policy_document.github_ci_ecr.json,
    data.aws_iam_policy_document.github_ci_eks.json,
  ]
}

# ── 6. IAM Role ───────────────────────────────────────
resource "aws_iam_role" "github_ci" {
  name               = "${var.cluster_name}-github-ci"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  # Максимальна тривалість сесії — 1 година (для довгих CI/CD пайплайнів)
  max_session_duration = 3600

  tags = merge(var.tags, {
    Name        = "${var.cluster_name}-github-ci"
    Description = "GitHub Actions CI/CD IAM Role"
  })
}

resource "aws_iam_role_policy_attachment" "github_ci" {
  role       = aws_iam_role.github_ci.name
  policy_arn = aws_iam_policy.github_ci.arn
}

# ── 7. EKS aws-auth mapping для GitHub CI ─────────────
#
# Якщо ваш CI пайплайн виконує kubectl напряму (наприклад, деплой Helm-ом),
# додайте GitHub CI Role до aws-auth ConfigMap.
#
# ⚠️  Якщо ви використовуєте ArgoCD (як у вашому проєкті) — цей блок НЕ
#    ПОТРІБЕН. GitHub CI лише оновлює GitOps-репозиторій, а ArgoCD синхронізує
#    стан у кластері. Це рекомендований патерн.
#
# Якщо все ж потрібен kubectl доступ — розкоментуйте блок нижче,
# попередньо налаштувавши kubernetes provider (вже є в main.tf).

# resource "kubernetes_config_map_v1_data" "aws_auth" {
#   count = var.create_aws_auth_ci_mapping ? 1 : 0
#
#   metadata {
#     name      = "aws-auth"
#     namespace = "kube-system"
#   }
#
#   data = {
#     mapRoles = yamlencode([
#       {
#         rolearn  = aws_iam_role.github_ci.arn
#         username = "github-ci"
#         groups   = var.github_ci_k8s_groups
#       }
#     ])
#   }
#
#   depends_on = [
#     module.eks,
#     aws_iam_role.github_ci,
#   ]
# }

# ── 8. Output: команда для ручного додавання в aws-auth ──
output "github_ci_role_arn" {
  description = "ARN of the GitHub CI IAM Role. Use this to manually add to aws-auth if needed."
  value       = aws_iam_role.github_ci.arn
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC Identity Provider."
  value       = aws_iam_openid_connect_provider.github.arn
}
