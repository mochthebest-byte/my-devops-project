# ══════════════════════════════════════════════════════════
#  Velero — backup & restore для EKS + PV
# ══════════════════════════════════════════════════════════

# ─── S3 Bucket для бекапів ───────────────────────────
resource "aws_s3_bucket" "velero" {
  bucket = "${var.project_name}-velero-backups-${data.aws_caller_identity.current.account_id}"
  tags   = var.tags
}

resource "aws_s3_bucket_public_access_block" "velero" {
  bucket = aws_s3_bucket.velero.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "velero" {
  bucket = aws_s3_bucket.velero.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "velero" {
  bucket = aws_s3_bucket.velero.id

  rule {
    id     = "expire-old-backups"
    status = "Enabled"

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# ─── IAM Role для Velero (IRSA) ──────────────────────
data "aws_iam_policy_document" "velero_assume" {
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
      values   = ["system:serviceaccount:velero:velero"]
    }
  }
}

data "aws_iam_policy_document" "velero_s3" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
    ]
    resources = [
      aws_s3_bucket.velero.arn,
      "${aws_s3_bucket.velero.arn}/*",
    ]
  }

  statement {
    actions = [
      "ec2:DescribeSnapshots",
      "ec2:DescribeVolumes",
      "ec2:CreateSnapshot",
      "ec2:CreateTags",
      "ec2:DeleteSnapshot",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "velero" {
  name               = "${var.project_name}-velero"
  assume_role_policy = data.aws_iam_policy_document.velero_assume.json
  tags               = var.tags
}

resource "aws_iam_policy" "velero_s3" {
  name   = "${var.project_name}-velero-s3"
  policy = data.aws_iam_policy_document.velero_s3.json
}

resource "aws_iam_role_policy_attachment" "velero_s3" {
  policy_arn = aws_iam_policy.velero_s3.arn
  role       = aws_iam_role.velero.name
}

# ══════════════════════════════════════════════════════════
#  CloudNativePG — barman-cloud backup (S3)
# ══════════════════════════════════════════════════════════

data "aws_iam_policy_document" "cnpg_backup_assume" {
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
      values   = [
        "system:serviceaccount:voting-app:pg-vote",
        "system:serviceaccount:keycloak:pg-keycloak",
      ]
    }
  }
}

data "aws_iam_policy_document" "cnpg_backup_s3" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
    ]
    resources = [
      aws_s3_bucket.velero.arn,
      "${aws_s3_bucket.velero.arn}/*",
    ]
  }
}

resource "aws_iam_role" "cnpg_backup" {
  name               = "${var.project_name}-cnpg-backup"
  assume_role_policy = data.aws_iam_policy_document.cnpg_backup_assume.json
  tags               = var.tags
}

resource "aws_iam_policy" "cnpg_backup_s3" {
  name   = "${var.project_name}-cnpg-backup-s3"
  policy = data.aws_iam_policy_document.cnpg_backup_s3.json
}

resource "aws_iam_role_policy_attachment" "cnpg_backup_s3" {
  policy_arn = aws_iam_policy.cnpg_backup_s3.arn
  role       = aws_iam_role.cnpg_backup.name
}
