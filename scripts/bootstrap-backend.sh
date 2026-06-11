#!/bin/bash
# ══════════════════════════════════════════════════════════
#  Bootstrap — створити S3 bucket + DynamoDB для Terraform
#  Виконати ОДИН РАЗ перед terraform init
# ══════════════════════════════════════════════════════════
set -euo pipefail

BUCKET="voting-app-tfstate-$(aws sts get-caller-identity --query Account --output text)"
REGION="${AWS_REGION:-eu-central-1}"
TABLE="voting-app-tfstate-lock"

echo "=== 1. S3 bucket: $BUCKET ==="
if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "✅ Вже існує"
else
  aws s3 mb "s3://$BUCKET" --region "$REGION"
  aws s3api put-bucket-versioning \
    --bucket "$BUCKET" \
    --versioning-configuration Status=Enabled
  aws s3api put-bucket-server-side-encryption \
    --bucket "$BUCKET" \
    --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
  echo "✅ Створено"
fi

echo ""
echo "=== 2. DynamoDB table: $TABLE ==="
if aws dynamodb describe-table --table-name "$TABLE" 2>/dev/null; then
  echo "✅ Вже існує"
else
  aws dynamodb create-table \
    --table-name "$TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION"
  echo "✅ Створено"
fi

echo ""
echo "=== Готово! ==="
echo "S3:       $BUCKET"
echo "DynamoDB: $TABLE"
echo "Region:   $REGION"
echo ""
echo "Тепер виконай: cd infra-aws && terraform init"
