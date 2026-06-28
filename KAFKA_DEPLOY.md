# Deploy Kafka via ArgoCD

## Спосіб 1: Через ArgoCD (рекомендовано)

Вже створено ArgoCD Application template в `charts/argocd-apps/templates/strimzi.yaml`.

```bash
# 1. Запустити root-app sync
kubectl patch application root-app -n argocd --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# 2. Зачекати поки ArgoCD створить strimzi Application
# 3. Sync strimzi Application в ArgoCD UI або:
kubectl patch application strimzi -n argocd --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

## Спосіб 2: Через Helm CLI напряму

```bash
# Якщо ArgoCD не справляється з CRDs:
kubectl delete application strimzi -n argocd

# Встановити Strimzi operator
kubectl create namespace kafka
kubectl apply -f "https://strimzi.io/install/latest?namespace=kafka"

# Зачекати поки operator запуститься
kubectl wait -n kafka --for=condition=ready pod -l name=strimzi-cluster-operator --timeout=120s

# Створити Kafka кластер
kubectl apply -f charts/strimzi-kafka/templates/kafka-cluster.yaml

# Перевірити
kubectl get pods -n kafka -w
```

## Нотатки
- Strimzi використовує образи з `quay.io/strimzi/` — Docker Hub не потрібен
- При першому запуску ArgoCD може не створити Kafka CR (CRDs ще не готові) — запустити sync повторно
- `SkipDryRunOnMissingResource=true` в Kafka CR допомагає ArgoCD пропустити dry-run помилки
