#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# Post-Provisioning Setup for EKS Cluster (Phase 6)
# ──────────────────────────────────────────────────────────────
set -euo pipefail

CLUSTER_NAME="${1:-my-app-eks}"
REGION="${2:-eu-north-1}"

echo "============================================"
echo " Phase 6 — EKS Post-Provisioning Setup"
echo " Cluster : ${CLUSTER_NAME}"
echo " Region  : ${REGION}"
echo "============================================"

# ── 1. Update kubeconfig ─────────────────────────
echo ""
echo "━━━ [1/3] Updating kubeconfig ─────────────────"
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${REGION}" --alias "${CLUSTER_NAME}"

echo ""
echo "✅ kubeconfig updated. Context: ${CLUSTER_NAME}"
echo "   → Перевірка: kubectl cluster-info"
echo "   → Перевірка: kubectl get nodes"

# ── 2. Install ArgoCD ────────────────────────────
echo ""
echo "━━━ [2/3] Installing ArgoCD ───────────────────"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo ""
echo "✅ ArgoCD manifests applied."
echo "   → Перевірка: kubectl get pods -n argocd -w"
echo "   → (чекайте, поки всі pods будуть Running/Completed)"
echo ""
echo "   Після запуску — отримати пароль адміна:"
echo "   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo"
echo ""
echo "   Проброс порту для UI:"
echo "   kubectl port-forward -n argocd svc/argocd-server 8080:443"

# ── 3. Default StorageClass gp3 ──────────────────
echo ""
echo "━━━ [3/3] Creating default StorageClass gp3 ───"
cat <<'EOF' | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: true
parameters:
  type: gp3
  encrypted: "true"
EOF

echo ""
echo "✅ StorageClass gp3 created (as default)."
echo "   → Перевірка: kubectl get sc"
echo "   → (шукайте '(default)' біля gp3)"

echo ""
echo "============================================"
echo " Setup complete!"
echo "============================================"
