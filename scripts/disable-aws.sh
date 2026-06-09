#!/bin/bash
# Disable AWS Terraform files — rename .tf → .tf.disabled
# This prevents terraform errors when AWS account is closed.
# To re-enable: run scripts/enable-aws.sh

set -euo pipefail

echo "Disabling AWS Terraform files..."
cd "$(dirname "$0")/../infra-aws"

for f in *.tf; do
  if [ "$f" = "terraform.tfstate" ] || [ "$f" = ".terraform.lock.hcl" ]; then
    continue
  fi
  if echo "$f" | grep -q "\.disabled$"; then
    continue
  fi
  mv "$f" "${f}.disabled"
  echo "  $f -> ${f}.disabled"
done

echo ""
echo "✅ AWS Terraform disabled. Run 'terraform plan' will now show:"
echo "   No configuration files (directory is empty)"
echo ""
echo "To re-enable: ./scripts/enable-aws.sh"
