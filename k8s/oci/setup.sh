#!/bin/bash
# ══════════════════════════════════════════════════════════
#  One-command setup for OCI (Oracle Kubernetes Engine)
#  Виконувати після того, як oci terraform apply готовий
# ══════════════════════════════════════════════════════════
set -euo pipefail

NAMESPACE="voting-app"

echo "=== 1. Ingress-NGINX ==="
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.0/deploy/static/provider/cloud/deploy.yaml
kubectl wait --namespace ingress-nginx --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller --timeout=180s

echo ""
echo "=== 2. Namespace ==="
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "=== 3. PostgreSQL secret + Helm install ==="
helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null
helm repo update

# DEV ONLY: створюємо Secret вручну (без ESO).
# В production секрет створюється через ESO з AWS Secrets Manager.
kubectl create secret generic postgresql \
  --namespace "$NAMESPACE" \
  --from-literal=password=testpass \
  --from-literal=postgres-password=testpass \
  --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install postgresql bitnami/postgresql \
  --namespace "$NAMESPACE" --version 16.x \
  --set auth.database=db --set auth.username=vote_user \
  --set auth.existingSecret=postgresql

helm upgrade --install redis bitnami/redis \
  --namespace "$NAMESPACE" --version 21.x \
  --set auth.enabled=false

echo ""
echo "=== 4. Build & Push до OCI Registry ==="
echo "Виконати вручну після налаштування OCI CLI:"
echo "  docker build -t <region>.ocir.io/<tenancy>/voting-app/vote:latest voting-app-vote/"
echo "  docker push <region>.ocir.io/<tenancy>/voting-app/vote:latest"
echo "  # ... аналогічно для result та worker"

echo ""
echo "=== 5. Helm Deploy ==="
# Заміни <region> та <tenancy> на свої значення
helm upgrade --install vote voting-app-vote/charts/vote --namespace "$NAMESPACE" \
  --set image.repository=<region>.ocir.io/<tenancy>/voting-app/vote \
  --set image.tag=latest --set postgresql.host=postgresql --set redis.host=redis-master

helm upgrade --install result voting-app-result/charts/result --namespace "$NAMESPACE" \
  --set image.repository=<region>.ocir.io/<tenancy>/voting-app/result \
  --set image.tag=latest --set postgresql.host=postgresql

helm upgrade --install worker voting-app-worker/charts/worker --namespace "$NAMESPACE" \
  --set image.repository=<region>.ocir.io/<tenancy>/voting-app/worker \
  --set image.tag=latest --set postgresql.host=postgresql --set redis.host=redis-master

echo ""
echo "=== 6. Ingress ==="
kubectl apply -f - << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: voting-app-ingress
  namespace: voting-app
  annotations:
    # Для OKE Load Balancer — закоментувати якщо ingress-nginx
    # kubernetes.io/ingress.class: "nginx"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - vote.mochthebest.io
    - result.mochthebest.io
    secretName: voting-app-tls
  rules:
  - host: vote.mochthebest.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: vote
            port:
              number: 5000
  - host: result.mochthebest.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: result
            port:
              number: 81
EOF

echo ""
echo "=== 7. Отримати IP Load Balancer ==="
echo "Зачекай 2-3 хвилини, потім:"
echo "  kubectl get svc -n ingress-nginx ingress-nginx-controller"
echo "  # External-IP → це твій публічний IP"
echo "  # Додай A-записи: vote.mochthebest.io → External-IP"

echo ""
echo "✅ Done!"
