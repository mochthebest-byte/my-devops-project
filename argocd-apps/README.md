# ArgoCD Applications — App-of-Apps

ArgoCD Application manifests that define the voting-app deployment.

## Structure

Each `.yaml` file declares an ArgoCD `Application` resource that points to a Helm chart or k8s manifests:

| File | Target | Source |
|------|--------|--------|
| `root-app.yaml` | Root App-of-Apps | `argocd-apps/` directory |
| `voting-app.yaml` | Vote service | `mochthebest-byte/gitops/apps/vote` |
| `result.yaml` | Result service | `mochthebest-byte/gitops/apps/result` |
| `worker.yaml` | Worker service | `mochthebest-byte/gitops/apps/worker` |
| `gateway-config.yaml` | Gateway + infra | `k8s/` directory |
| `keycloak.yaml` | Keycloak SSO | `keycloak/charts/keycloak` |
| `keycloak-postgresql.yaml` | Keycloak DB | bitnami/postgresql chart |
| `postgresql.yaml` | Voting DB | bitnami/postgresql chart |
| `redis.yaml` | Cache | bitnami/redis chart |

## Sync Flow

```
root-app (argocd-apps/)
├── voting-app → GitOps repo → Helm → EKS
├── result → GitOps repo → Helm → EKS
├── worker → GitOps repo → Helm → EKS
├── postgresql → bitnami chart → EKS
├── redis → bitnami chart → EKS
├── gateway-config → k8s/ manifests → EKS
├── keycloak → Helm chart → EKS
└── keycloak-postgresql → bitnami chart → EKS
```
