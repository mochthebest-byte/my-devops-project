# ══════════════════════════════════════════════════════════
#  ECR Repositories — для multi-arch образів сервісів
# ══════════════════════════════════════════════════════════
#
#  Кожен сервіс має свій ECR-репозиторій:
#    my-app/vote, my-app/result, my-app/worker
#
#  Використовується: CI (GitHub Actions) → Buildx multi-arch → ECR → GitOps → ArgoCD

locals {
  ecr_repositories = {
    vote   = "my-app/vote"
    result = "my-app/result"
    worker = "my-app/worker"
  }
}

resource "aws_ecr_repository" "this" {
  for_each = local.ecr_repositories

  name                 = each.value
  image_tag_mutability = "MUTABLE"
  force_delete         = true # дозволяє terraform destroy видалити репо

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${each.key}"
  })
}

# ─── Lifecycle policy: видаляти старі теги (економія) ──
resource "aws_ecr_lifecycle_policy" "this" {
  for_each = aws_ecr_repository.this

  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images, expire older"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}
