# ═══════════════════════════════════════════════════════════════════
#  Terraform S3 Backend
# ═══════════════════════════════════════════════════════════════════
#  ⚠️  Account ID в назві бакету — хардкод, оскільки backend
#      ініціалізується ДО завантаження провайдерів, тому
#      data.aws_caller_identity.current.account_id недоступний.
#
#  При зміні AWS акаунта — змінити назву бакету ТУТ і в
#  bucket_prefix ресурсу aws_s3_bucket.tfstate в state-bucket.tf.
# ═══════════════════════════════════════════════════════════════════

bucket         = "voting-app-tfstate-657954628960"
key            = "voting-app/terraform.tfstate"
region         = "eu-central-1"
dynamodb_table = "voting-app-tfstate-lock"
encrypt        = true
