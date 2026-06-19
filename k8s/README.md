# Kubernetes — legacy manifests

> **⚠️  Ці файли залишені для локальної розробки.**
> Виробничі ресурси управляються через Helm-чарти + ArgoCD.

## Файли

| Файл | Призначення |
|------|-------------|
| `local/values-local.yaml` | Helm overrides для локального Kind кластера |
| `local/values-grafana-local.yaml` | Grafana overrides для локального Kind кластера |

## Деплой

- **Production:** `charts/infra-bootstrap/` (ClusterSecretStore, ExternalSecrets) +
  `charts/gateway-config/` (Gateway, HTTPRoutes, ExternalDNS)
- **Local:** `k8s/local/values-*.yaml` + `helm upgrade --install -f ...`

## Migration status

| Legacy file | Helm chart | Status |
|-------------|-----------|--------|
| `secretstore.yaml` | `charts/infra-bootstrap/` | ✅ Migrated |
| `postgres-external-secret.yaml` | `charts/infra-bootstrap/` | ✅ Migrated |
| `grafana-oidc-external-secret.yaml` | `charts/infra-bootstrap/` | ✅ Migrated |
| `cluster-issuer.yaml` | Видалено (TLS = ACM) | ✅ Removed |

## Dependencies

- External Secrets Operator (встановлено через Terraform)
- AWS Load Balancer Controller (Terraform + Helm)
