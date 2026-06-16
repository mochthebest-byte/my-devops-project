# Kubernetes Infrastructure Manifests

Shared k8s resources applied via ArgoCD (`gateway-config` app).

## Files

| File | Kind | Purpose |
|------|------|---------|
| `gateway-config.yaml` | GatewayClass + Gateway | ALB for HTTP/HTTPS traffic |
| `secretstore.yaml` | ClusterSecretStore | AWS Secrets Manager backend for ESO |
| `postgres-external-secret.yaml` | ExternalSecret | PostgreSQL password from Secrets Manager |
| `grafana-oidc-external-secret.yaml` | ExternalSecret | Grafana OIDC client secret from Secrets Manager |
| `cluster-issuer.yaml` | ClusterIssuer + Certificate | Let's Encrypt + self-signed TLS |

> **Примітка:** Усі HTTPRoute (vote, result, grafana, keycloak) тепер в одному файлі `gateway-config.yaml`, а не окремими файлами.

## Dependencies

- External Secrets Operator (installed via Terraform)
- cert-manager (installed via Terraform)
- AWS Load Balancer Controller (installed via Terraform, IAM + Helm в `infra-aws/addons.tf`)
