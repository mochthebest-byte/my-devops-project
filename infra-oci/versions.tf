terraform {
  required_version = ">= 1.6"

  # ─── Remote State: OCI Object Storage ────────────────
  # Після першого terraform apply (створить bucket):
  #   1. Розкоментуй backend нижче
  #   2. terraform init -migrate
  #   3. Видали локальний terraform.tfstate
  #
  # backend "s3" {
  #   bucket                      = "voting-app-tfstate"
  #   key                         = "oke/terraform.tfstate"
  #   region                      = "eu-frankfurt-1"
  #   endpoint                    = "https://eu-frankfurt-1.compat.objectstorage.eu-frankfurt-1.oraclecloud.com"
  #   skip_region_validation      = true
  #   skip_credentials_validation = true
  #   skip_requesting_account_id  = true
  #   skip_metadata_api_check     = true
  #   use_path_style              = true
  # }

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
  }
}
