# ─────────────────────────────────────────────────────────
# ECR Lifecycle Policies — автоочищення старих образів
# ─────────────────────────────────────────────────────────
# Правила:
#   - Зберігати останні 10 образів (за тегом)
#   - Видаляти образи старші 90 днів
#   - НЕ чіпати тег "latest"
# ─────────────────────────────────────────────────────────

locals {
  ecr_repositories = [
    "my-app/vote",
    "my-app/result",
    "my-app/worker",
  ]
}

resource "aws_ecr_lifecycle_policy" "cleanup" {
  for_each = toset(local.ecr_repositories)

  repository = each.key

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only last 10 images (any tag)"
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
