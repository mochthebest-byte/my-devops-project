#!/bin/bash
# Re-enable AWS Terraform files — rename .tf.disabled → .tf

set -euo pipefail

echo "Re-enabling AWS Terraform files..."
cd "$(dirname "$0")/../infra-aws"

found=0
for f in *.tf.disabled; do
  newname="${f%.disabled}"
  mv "$f" "$newname"
  echo "  $f -> $newname"
  found=1
done

if [ "$found" = "0" ]; then
  echo "  (no disabled files found)"
fi

echo ""
echo "✅ AWS Terraform enabled."
