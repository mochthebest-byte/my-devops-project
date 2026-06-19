# Kubernetes Infrastructure Manifests

Shared k8s resources applied via ArgoCD (`gateway-config` app).

## Files

| File | Kind | Purpose |
|------|------|---------|
| `gateway-config.yaml.helm-migrated` | GatewayClass + Gateway | ALB for HTTP/HTTPS traffic (migrated to Helm) |
| `secretstore.yaml` | ClusterSecretStore | AWS Secrets Manager backend for ESO |
| `postgres-external-secret.yaml` | ExternalSecret | PostgreSQL password from Secrets Manager |
| `grafana-oidc-external-secret.yaml` | ExternalSecret | Grafana OIDC client secret from Secrets Manager |
| `cluster-issuer.yaml` | ClusterIssuer + Certificate | Let's Encrypt + self-signed TLS |

> **Примітка:** Усі HTTPRoute (vote, result, grafana, keycloak) тепер в одному файлі `gateway-config.yaml`, а не окремими файлами.

## Migration to Helm

Файли в `k8s/` застосовуються напряму (kubectl), що порушує принцип "деплой тільки через Helm".
Для міграції створено Helm-чарт `charts/infra-bootstrap/`, який вміщує всі ці ресурси:

| k8s/ файл | Helm template |
|-----------|---------------|
| `cluster-issuer.yaml` | `charts/infra-bootstrap/templates/cluster-issuer.yaml` |
| `secretstore.yaml` | `charts/infra-bootstrap/templates/secretstore.yaml` |
| `grafana-oidc-external-secret.yaml` | `charts/infra-bootstrap/templates/external-secrets.yaml` |
| `postgres-external-secret.yaml` | `charts/infra-bootstrap/templates/external-secrets.yaml` |

Після створення ArgoCD Application для `charts/infra-bootstrap`:
1. Додати `charts/argocd-apps/templates/infra-bootstrap.yaml`
2. Переконатися що ресурси створились коректно
3. Видалити ручні kubectl apply

## Dependencies

- External Secrets Operator (installed via Terraform)
- cert-manager (installed via Terraform)
- AWS Load Balancer Controller (installed via Terraform, IAM + Helm в `infra-aws/addons.tf`)
