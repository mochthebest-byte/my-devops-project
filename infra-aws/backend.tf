# ══════════════════════════════════════════════════════════
#  Remote Backend — S3 + DynamoDB
#  Перед terraform init виконати:
#    bash ../scripts/bootstrap-backend.sh
#  Потім:
#    terraform init -backend-config=backend.hcl
# ══════════════════════════════════════════════════════════
terraform {
  backend "s3" {
    encrypt = true
  }
}
