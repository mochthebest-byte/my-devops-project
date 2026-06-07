# Keycloak Helm Chart

Helm chart for deploying Keycloak with Gateway API HTTPRoute and External Secrets.

## What it deploys

- **StatefulSet**: Keycloak 26.0.0 with PostgreSQL backend
- **Service**: ClusterIP on port 8080
- **ConfigMap**: Realm import (`myapp` realm with Grafana OIDC client, test users, roles)
- **HTTPRoute**: Exposes Keycloak via the shared Gateway
- **ExternalSecret**: PostgreSQL password from AWS Secrets Manager

## Dependencies

- PostgreSQL (deployed separately via `bitnami/postgresql` chart)
- ClusterSecretStore `aws-secretsmanager` (from `k8s/secretstore.yaml`)
- Gateway `voting-app-gateway` (from `k8s/gateway-config.yaml`)

## Values

| Parameter | Default | Description |
|-----------|---------|-------------|
| `replicaCount` | `1` | Number of replicas |
| `image.tag` | `26.0.0` | Keycloak version |
| `admin.user` | `admin` | Bootstrap admin username |
| `admin.password` | `admin123` | Bootstrap admin password |
| `hostname` | `keycloak.34.194.59.190.nip.io` | Keycloak hostname |
| `postgresql.host` | `keycloak-postgresql.keycloak.svc` | PostgreSQL host |
| `postgresql.existingSecret` | `keycloak-db` | Secret for DB password (from ExternalSecret) |

## Deployment via ArgoCD

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: keycloak
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/mochthebest-byte/my-devops-project.git
    path: keycloak/charts/keycloak
  destination:
    namespace: keycloak
```
