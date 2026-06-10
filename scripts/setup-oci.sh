#!/bin/bash
# ──────────────────────────────────────────────────────────
#  OCI Setup — одноразове налаштування
# ──────────────────────────────────────────────────────────
set -euo pipefail

echo "=== 1. Встановлення OCI CLI ==="
if ! which oci &>/dev/null; then
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"
fi
oci --version

echo ""
echo "=== 2. Налаштування OCI CLI ==="
echo "Відкрий браузер: OCI Console → Profile → API Keys → Generate"
echo "Завантаж PEM-ключ, запиши:"
echo "  - Tenancy OCID"
echo "  - User OCID"
echo "  - Fingerprint"
echo "  - Регіон (напр. eu-frankfurt-1)"
echo ""
read -p "Натисни Enter після налаштування..."

oci setup config

echo ""
echo "=== 3. Ініт Terraform ==="
cd "$(dirname "$0")/infra-oci"
if [ ! -f terraform.tfvars ]; then
  cp terraform.tfvars.example terraform.tfvars
  echo "Заповни terraform.tfvars своїми даними, потім:"
  echo "  cd infra-oci && terraform init && terraform apply"
else
  echo "terraform.tfvars вже існує."
fi

echo ""
echo "✅ Готово! Після заповнення terraform.tfvars:"
echo "  cd infra-oci"
echo "  terraform init"
echo "  terraform plan"
echo "  terraform apply"
