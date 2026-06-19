# Infra Bootstrap Helm Chart

Cluster-level інфраструктурні ресурси для EKS.

## Вміст

| Ресурс | Опис |
|--------|------|
| ClusterIssuer (letsencrypt-staging, letsencrypt-prod, selfsigned) | ACME та self-signed видавці сертифікатів |
| Certificate (self-signed + LE staging) | TLS сертифікати для сервісів |
| ClusterSecretStore (aws-secretsmanager) | Підключення до AWS Secrets Manager через ESO |
| ExternalSecret (grafana-oidc) | OIDC client secret для Grafana |
| ExternalSecret (postgresql) | Пароль PostgreSQL |

## Деплой через ArgoCD

```yaml
# charts/argocd-apps/templates/infra-bootstrap.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: infra-bootstrap
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/mochthebest-byte/my-devops-project.git
    targetRevision: HEAD
    path: charts/infra-bootstrap
    helm:
      values: |
        global:
          enabled: true
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

> ⚠️  Перед деплоєм через ArgoCD переконайтеся, що ESO та cert-manager вже встановлені (Terraform addons).

## Migration

Після деплою через ArgoCD:
1. Переконайтеся що всі ресурси створились: `kubectl get clusterissuer,clustersecretstore`
2. Перевірте ExternalSecrets: `kubectl get externalsecret -A`
3. Видаліть ручні манифести з `k8s/` (але не gateway-config.yaml.helm-migrated — він історичний)
