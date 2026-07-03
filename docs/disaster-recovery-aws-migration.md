# ☢️ Disaster Recovery: Migrate to a New AWS Account

> **Коли використовувати:** Втрата доступу до AWS акаунта `657954628960`, потрібно
> відновити всю інфраструктуру в новому акаунті з нуля.
>
> **Ціль:** `terraform apply` + ArgoCD sync → все працює без ручних кроків.

---

## Phase 0 — Підготовка нового акаунта

### 0.1 Отримати новий Account ID

```bash
aws sts get-caller-identity --query Account --output text
# → 123456789012  (записати як <NEW_ACCOUNT_ID>)
```

### 0.2 Встановити GitHub variable

```bash
gh variable set AWS_ACCOUNT_ID \
  --repo mochthebest-byte/my-devops-project \
  --body <NEW_ACCOUNT_ID>
```

### 0.3 GitHub Secrets (не тільки vars)

```bash
# GitHub OIDC variable (вже є в інструкції)
gh variable set AWS_ACCOUNT_ID \
  --repo mochthebest-byte/my-devops-project \
  --body <NEW_ACCOUNT_ID>

# Додаткові GitHub Secrets
gh secret set GITOPS_PAT \
  --repo mochthebest-byte/my-devops-project \
  --body "<github-pat-token>"
```

> `GITOPS_PAT` — Personal Access Token з правами `contents:write` для репо `mochthebest-byte/gitops`. Якщо GitOps репо не використовується — секрет не обов'язковий, CI продовжить (`continue-on-error: true`).

### 0.4 Налаштувати AWS CLI для нового акаунта

```bash
aws configure sso  # або aws configure --profile new-account
export AWS_PROFILE=new-account
```

---

## Phase 1 — Оновити код (commit в Git)

### 1.1 Account ID — хардкод (3 файли)

| № | Файл | Зміна |
|---|---|---|
| 1 | `charts/argocd-apps/values.yaml:14` | `awsAccountId: "<NEW_ACCOUNT_ID>"` |
| 2 | `charts/karpenter-resources/values.yaml:7` | `awsAccountId: "<NEW_ACCOUNT_ID>"` |
| 3 | `infra-aws/backend.hcl:12` | `bucket = "voting-app-tfstate-<NEW_ACCOUNT_ID>"` |

### 1.2 Terraform state backend

| № | Файл | Зміна |
|---|---|---|
| 3 | `infra-aws/backend.hcl:12` | `bucket = "voting-app-tfstate-<NEW_ACCOUNT_ID>"` |

> `backend.tf` використовує `terraform { backend "s3" { encrypt = true } }` без хардкоду — налаштування підтягуються з `backend.hcl`. Змінювати `backend.tf` не потрібно.

### 1.3 EKS публічний доступ (ваш IP)

| № | Файл | Зміна |
|---|---|---|
| 4 | `infra-aws/terraform.tfvars:18` | `eks_public_access_cidrs = ["<ВАШ_ПУБЛІЧНИЙ_IP>/32"]` |

Якщо у вас динамічний IP — використовуйте `0.0.0.0/0` (або встановіть `cluster_endpoint_public_access = false`, якщо є VPN/прямий доступ до VPC).

### 1.4 ACM certificate (новий в новому акаунті)

Після `terraform apply` отримати новий cert ID:

```bash
terraform output acm_certificate_arn
# → arn:aws:acm:eu-central-1:<NEW_ACCOUNT_ID>:certificate/NEW-UUID-HERE
```

| № | Файл | Зміна |
|---|---|---|
| 5 | `charts/gateway-config/values.yaml:25` | `acmCertificateId: "NEW-UUID-HERE"` |

### 1.5 EKS cluster endpoint

Після створення EKS:

```bash
terraform output cluster_endpoint
# → https://XXXXXX.gr7.eu-central-1.eks.amazonaws.com
```

| № | Файл | Зміна |
|---|---|---|
| 6 | `charts/argocd-apps/values.yaml:19` | `clusterEndpoint: "https://XXXXXX.gr7.eu-central-1.eks.amazonaws.com"` |

### 1.6 Node group sizing

Перед apply варто скоригувати розмір node group, щоб не створювати зайві ноди:

| № | Файл | Зміна |
|---|---|---|
| 7 | `infra-aws/terraform.tfvars:11` | `eks_desired_nodes = 5` (було 20) |
| 8 | `infra-aws/terraform.tfvars:12` | `eks_min_nodes = 3` (було 6) |
| 9 | `infra-aws/terraform.tfvars:13` | `eks_max_nodes = 10` (було 20) |

> ⚠️ Також перевірити `eks_node_instance_types` — якщо бажаєте spot замість on-demand, додайте `"t3.small"` до списку або змініть повністю.

### 1.7 GitHub org (якщо змінюється)

| № | Файл | Зміна |
|---|---|---|
| 10 | `infra-aws/variables.tf:97` | `default = ["new-org/my-devops-project", "new-org/voting-app"]` |
| 11 | `.github/workflows/deploy-voting-app.yml:40` | `--repo new-org/my-devops-project` |
| 12 | `.github/workflows/deploy-voting-app.yml:43` | `GITOPS_REPO: new-org/gitops` |
| 13 | `.github/workflows/deploy-voting-app.yml:88` | `repository: new-org/voting-app` |
| 14 | `root-app.yaml:9` | `repoURL: https://github.com/new-org/my-devops-project.git` |
| 15 | `charts/root-app/templates/root-app.yaml:9` | `repoURL: https://github.com/new-org/my-devops-project.git` |
| 16 | **18×** `charts/argocd-apps/templates/*.yaml:11` | `repoURL: https://github.com/new-org/my-devops-project.git` |

> Список усіх 18 ArgoCD Application template файлів:
> `cert-manager-issuers.yaml`, `cnpg-clusters.yaml`, `gateway-config.yaml`,
> `infra-bootstrap.yaml`, `karpenter.yaml`, `karpenter-resources.yaml`,
> `keycloak.yaml`, `kyverno-policies.yaml`, `loki-tempo.yaml`,
> `rabbitmq.yaml`, `rabbitmq-operator.yaml`, `result.yaml`,
> `argo-rollout-vote.yaml`, `vault-init.yaml`, `vault-vote-secrets.yaml`,
> `voting-app.yaml`, `vso-config.yaml`, `worker.yaml`

### 1.8 Domain (якщо змінюється)

Пошук `mochthebest.pp.ua` → замінити на новий домен у всіх файлах нижче.

**Terraform:**

| № | Файл | Зміна |
|---|---|---|
| 17 | `infra-aws/terraform.tfvars:18` | `domain_name = "new-domain.com"` |
| 18 | `infra-aws/variables.tf:64` (default) | `default = "new-domain.com"` |
| 19 | `infra-aws/budget.tf:23,31` | `admin@new-domain.com` (2 місця) |

**Gateway routes (8 значень в одному файлі):**

| № | Файл | Зміна |
|---|---|---|
| 20 | `charts/gateway-config/values.yaml:16` | `domain: new-domain.com` |
| 21 | `charts/gateway-config/values.yaml:46` | `"vote.new-domain.com"` |
| 22 | `charts/gateway-config/values.yaml:55` | `"result.new-domain.com"` |
| 23 | `charts/gateway-config/values.yaml:64` | `"grafana.new-domain.com"` |
| 24 | `charts/gateway-config/values.yaml:73` | `"keycloak.new-domain.com"` |
| 25 | `charts/gateway-config/values.yaml:82` | `"argocd.new-domain.com"` |
| 26 | `charts/gateway-config/values.yaml:91` | `"rollouts.new-domain.com"` |

**Monitoring / Keycloak / Cert Manager:**

| № | Файл | Зміна |
|---|---|---|
| 27 | `monitoring-values.yaml:37-46` | 5× Grafana OIDC URLs з новим доменом |
| 28 | `keycloak/charts/keycloak/values.yaml:55` | `hostname: keycloak.new-domain.com` |
| 29 | `keycloak/charts/keycloak/values.yaml:130` | Grafana redirect URI |
| 30 | `charts/cert-manager-issuers/templates/cluster-issuers.yaml:15` | `email: admin@new-domain.com` |

**Argo Rollout аналіз (Prometheus metric labels):**

| № | Файл | Зміна |
|---|---|---|
| 31 | `charts/argo-rollout-vote/templates/analysis-template.yaml:18-19` | `host="vote.new-domain.com"` (2 місця) |

### 1.9 Commit

### 1.9 Commit

```bash
git add -A
git commit -m "chore: migrate AWS account <OLD> → <NEW>"
git push
```

> **⏱ Оцінка:** ~10-20 хв на пошук+заміну (sed або глобальний find-and-replace).
> **Порада:** Використайте `sed -i ''` для масової заміни:
> ```bash
> # Заміна Account ID
> sed -i '' 's/657954628960/<NEW_ACCOUNT_ID>/g' \
>   charts/argocd-apps/values.yaml \
>   charts/karpenter-resources/values.yaml \
>   infra-aws/backend.hcl
>
> # Заміна домену (якщо змінюється)
> sed -i '' 's/mochthebest\.pp\.ua/new-domain.com/g' \
>   infra-aws/terraform.tfvars \
>   infra-aws/variables.tf \
>   charts/gateway-config/values.yaml \
>   monitoring-values.yaml \
>   keycloak/charts/keycloak/values.yaml
> ```

---

## Phase 2 — Bootstrap Terraform state

### 2.1 Створити S3 bucket + DynamoDB для state

```bash
cd infra-aws

# Скрипт створить:
#   s3://voting-app-tfstate-<NEW_ACCOUNT_ID>
#   dynamodb://voting-app-tfstate-lock
bash ../scripts/bootstrap-backend.sh
```

Перевірити що створилось:

```bash
aws s3 ls | grep tfstate
aws dynamodb list-tables | grep tfstate
```

### 2.2 Ініціалізувати Terraform з новим бекендом

```bash
terraform init -reconfigure -backend-config=backend.hcl
```

---

## Phase 3 — Terraform apply (вся інфраструктура)

### 3.1 Перевірити план

```bash
terraform plan -out=tf.plan
```

Очікується **~200+ ресурсів** to create, 0 to change/destroy.
**ВАЖЛИВО:** Переконатись що не намагається видалити старі ресурси — їх немає в новому акаунті, це нормально.

### 3.2 Застосувати

```bash
terraform apply tf.plan
```

**Тривалість:** ~25-35 хв (EKS + ALB + ACM validation — найдовше).

Що створюється (ключове):
- **VPC** + subnets + NAT Gateway + Internet Gateway
- **EKS cluster** + node group
- **ECR repositories**: `my-app/vote`, `my-app/result`, `my-app/worker`
- **ACM wildcard certificate** + Route53 zone + validation
- **S3 buckets**: Velero backups (`voting-app-velero-backups-<ID>`), ALB logs
- **IAM roles**: GitHub CI OIDC, Karpenter controller, Velero, Cluster Autoscaler, EBS CSI driver, external-dns, ArgoCD Image Updater
- **Karpenter** instance profile + IAM role
- **AWS Budget** ($50/month) with notification

Після apply перевірити ключові ресурси:

```bash
terraform output aws_account_id         # → <NEW_ACCOUNT_ID>
terraform output cluster_endpoint       # → https://...
terraform output acm_certificate_arn    # → arn:aws:acm:...
terraform output github_ci_role_arn     # → arn:aws:iam::...
terraform output dns_nameservers        # → ns-xxx.awsdns-xx.net
terraform output ecr_repositories       # → map of repo URLs
terraform output alb_dns                # → ALB DNS name
```

> ⚠️ **Terraform user:** `terraform apply` створить access entry для `terraform-user`. Якщо ви не використовуєте цього користувача — ігноруйте помилку, це не критично. Головне — щоб `module.eks` створив кластер.

### 3.3 Оновити DNS у реєстратора

Nameservers з `terraform output dns_nameservers` вказати в панелі реєстратора
(наприклад, NIC.UA, Namecheap, Route53, тощо).

**⏱ Очікування:** DNS propagation може тривати від 5 хв до 24 год.

---

## Phase 4 — Оновити значення після apply

### 4.1 ACM certificate ID

```bash
CERT_ARN=$(terraform output -raw acm_certificate_arn)
CERT_ID=$(echo "$CERT_ARN" | awk -F'certificate/' '{print $2}')
echo "$CERT_ID"
```

Оновити `charts/gateway-config/values.yaml:25` → `acmCertificateId: "$CERT_ID"`

### 4.2 EKS cluster endpoint

```bash
terraform output -raw cluster_endpoint
```

Оновити `charts/argocd-apps/values.yaml:19` → отриманим значенням

### 4.3 Commit оновлень

```bash
git add charts/gateway-config/values.yaml charts/argocd-apps/values.yaml
git commit -m "fix: update ACM cert ID and EKS endpoint after apply"
git push
```

---

## Phase 5 — GitHub OIDC перевірка

### 5.1 Перевірити що IAM role створена

```bash
aws iam get-role --role-name my-app-eks-github-ci
```

### 5.2 Запушити перші Docker образи в ECR

Проблема: **ECR репозиторії порожні** після `terraform apply`. CI не може зібрати образи, бо ще не налаштований. ArgoCD не може задеплоїти апки, бо образів нема.

**Рішення — зібрати та запушіти вручну (один раз):**

```bash
# Автентифікація в ECR
aws ecr get-login-password --region eu-central-1 | \
  docker login --username AWS --password-stdin \
  <NEW_ACCOUNT_ID>.dkr.ecr.eu-central-1.amazonaws.com

# Vote
cd voting-app-vote
docker buildx build --platform linux/amd64 \
  -t <NEW_ACCOUNT_ID>.dkr.ecr.eu-central-1.amazonaws.com/my-app/vote:latest \
  --load .
docker push <NEW_ACCOUNT_ID>.dkr.ecr.eu-central-1.amazonaws.com/my-app/vote:latest

# Result
cd ../voting-app-result
docker buildx build --platform linux/amd64 \
  -t <NEW_ACCOUNT_ID>.dkr.ecr.eu-central-1.amazonaws.com/my-app/result:latest \
  --load .
docker push <NEW_ACCOUNT_ID>.dkr.ecr.eu-central-1.amazonaws.com/my-app/result:latest

# Worker
cd ../voting-app-worker
docker buildx build --platform linux/amd64 \
  -t <NEW_ACCOUNT_ID>.dkr.ecr.eu-central-1.amazonaws.com/my-app/worker:latest \
  --load .
docker push <NEW_ACCOUNT_ID>.dkr.ecr.eu-central-1.amazonaws.com/my-app/worker:latest
```

> **⏱ ~5-10 хв** (перша збірка — викачування залежностей)
> Після цього ArgoCD зможе задеплоїти апки з образом `:latest`.

### 5.3 Перевірити ручним workflow

В GitHub Actions:
- `Actions` → `🚀 Deploy voting-app` → `Run workflow`
- Вибрати `dev` + `vote` → `Run`

Переконатись що:
- OIDC auth проходить (role-to-assume з `vars.AWS_ACCOUNT_ID`)
- Docker образ збирається та пушиться в новий ECR
- Cosign signing + SBOM attestation проходять

### 5.4 Запушити перші образи в ECR (після CI)

Після першого успішного CI запуску переконатись що образи є в ECR:

```bash
aws ecr describe-images --repository-name my-app/vote
aws ecr describe-images --repository-name my-app/result
aws ecr describe-images --repository-name my-app/worker
```

---

## Phase 6 — ArgoCD bootstrap

### 6.1 Встановити ArgoCD в кластер

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

**⏱ Чекати ~2 хв** поки всі поди argocd стануть Ready.

### 6.2 Додати root-додаток

```bash
kubectl apply -f root-app.yaml
```

Це створить ArgoCD Application `root-app`, який синхронізує **всі 18 додатків** з `charts/argocd-apps/templates/`.

### 6.3 Отримати пароль admin

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

### 6.4 Дочекатись sync всіх додатків

```bash
argocd login --core
argocd app list
argocd sync --all
# або: argocd app sync root-app  # синхронізує всі дочірні рекурсивно
```

**Список додатків (18):**
1. `cert-manager-issuers`
2. `cnpg-clusters` (CloudNativePG)
3. `gateway-config`
4. `infra-bootstrap`
5. `karpenter`
6. `karpenter-resources`
7. `keycloak`
8. `kyverno-policies`
9. `loki-tempo`
10. `rabbitmq`
11. `rabbitmq-operator`
12. `result`
13. `argo-rollout-vote`
14. `vault-init`
15. `vault-vote-secrets`
16. `voting-app`
17. `vso-config`
18. `worker`

### 6.5 Перевірити що Route53 records створено (external-dns)

Після sync мають з'явитись ALB та DNS records:

```bash
kubectl get ingress -A
kubectl get svc -n envoy-gateway-system
```

Якщо DNS records не з'явились за 5 хв — перевірити logs external-dns:

```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns
```

### 6.6 Vault — ініціалізація

Vault буде автоматично ініціалізований та розпечатаний Job-ою `vault-init` (входить до 18 додатків). Перевірити:

```bash
kubectl logs -n vault -l job-name=vault-init --tail=20
# Очікується: "Vault initialized", "Vault unsealed", "Database engine configured"
```

Якщо vault-init не виконався:

```bash
# Запустити вручну
kubectl delete job -n vault vault-init
kubectl create job --from=cronjob/vault-init vault-init-manual -n vault
```

> Після успішного vault-init, VSO (Vault Secrets Operator) автоматично створить секрет `pg-vote-dynamic` в `voting-app`. Перевірити:
> ```bash
> kubectl get secret -n voting-app pg-vote-dynamic
> ```

### 6.7 Keycloak — початкове налаштування

Keycloak буде розгорнуто ArgoCD. Після sync:

```bash
# Отримати admin пароль
kubectl get secret -n keycloak keycloak -o jsonpath='{.data.admin-password}' | base64 -d

# Дочекатись готовності
kubectl wait --for=condition=ready pod -n keycloak -l app.kubernetes.io/name=keycloak --timeout=120s
```

Створити OIDC клієнта для Grafana (один раз, через UI):

1. Відкрити `https://keycloak.<DOMAIN>`
2. Login: `admin` / пароль з секрету
3. Realm `myapp` → Clients → Create
   - Client ID: `grafana`
   - Valid Redirect URIs: `https://grafana.<DOMAIN>/login/generic_oauth`

### 6.8 Grafana — admin доступ

Після деплою monitoring стеку:

```bash
# Отримати admin пароль
kubectl get secret -n monitoring monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d
```

Якщо Grafana налаштована на Keycloak SSO — логін через `https://grafana.<DOMAIN>`.
Для прямого доступу (без SSO): localhost:3000, admin / пароль з секрету.

---

## Phase 7 — Перевірка (контрольний тест)

### 7.1 Стан подів

```bash
kubectl get pods -A | grep -v Running | grep -v Completed
# → порожньо (все Running/Completed)
```

> ⚠️ Деякі поди можуть бути в `Pending` якщо кластер ще scaling up (додає нові ноди). Почекати 2-3 хв або перевірити node group:

```bash
kubectl get nodes
# Має бути хоча б 2-3 ноди Ready
```

### 7.2 Ендпоінти

```bash
curl -sI https://vote.mochthebest.pp.ua    # 200
curl -sI https://result.mochthebest.pp.ua  # 200
curl -sI https://argocd.mochthebest.pp.ua  # 200
curl -sI https://grafana.mochthebest.pp.ua # 200 (або 302 redirect на Keycloak)
curl -sI https://keycloak.mochthebest.pp.ua # 200
```

> 🐛 **Відома проблема:** Якщо Redis не розгорнуто, vote app повертає 500 на POST. Рішення — розгорнути Redis або переконатись що vote app використовує правильний код (без Redis залежності).

```bash
curl -sI https://vote.mochthebest.pp.ua    # 200
curl -sI https://result.mochthebest.pp.ua  # 200
curl -sI https://argocd.mochthebest.pp.ua  # 200
curl -sI https://grafana.mochthebest.pp.ua # 200
curl -sI https://keycloak.mochthebest.pp.ua # 200
```

### 7.3 ArgoCD — всі Healthy

```bash
argocd app list | grep -v Healthy
# → порожньо (все Healthy)
```

> ⚠️ Якщо якісь додатки `OutOfSync` — це нормально після першого деплою.
> Запустити `argocd sync --all --prune` ще раз.
>
> ⚠️ Додатки `karpenter`, `vault-init`, `vso-config` можуть бути `OutOfSync` через особливості їхніх CRD — це OK.

### 7.4 Секрети та Vault

```bash
# Dynamic DB secret від VSO
kubectl get secret -n voting-app pg-vote-dynamic -o jsonpath='{.data.username}' | base64 -d
# → v-kubernetes-voting-app-... (має бути non-empty)

# Якщо секрет пустий — перевірити Vault
kubectl logs -n vault -l job-name=vault-init --tail=10
kubectl logs -n vault-secrets-operator -l app.kubernetes.io/name=vault-secrets-operator --tail=10
```

### 7.5 Vault — статус

```bash
# Vault под має бути Running
kubectl get pod -n vault

# vault-init Job має завершитись (STATUS: Completed)
kubectl get job -n vault

# VSO має синхронізувати секрет
kubectl get VaultDynamicSecret -n voting-app pg-vote-dynamic
```

### 7.6 Keycloak — статус

```bash
kubectl wait --for=condition=ready pod -n keycloak -l app.kubernetes.io/name=keycloak --timeout=60s
# Отримати пароль admin:
kubectl get secret -n keycloak keycloak -o jsonpath='{.data.admin-password}' | base64 -d
```

### 7.7 Grafana — статус

```bash
# Grafana має бути доступна
curl -sI https://grafana.mochthebest.pp.ua
# → 302 (redirect на Keycloak) або 200

# Якщо SSO не налаштовано — admin пароль:
kubectl get secret -n monitoring monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d
```

### 7.8 Перевірка голосування

```bash
# За голосувати (через RabbitMQ — без Redis):
kubectl exec -n voting-app deploy/voting-app-vote -- python3 -c "
import app
app.get_rabbitmq().basic_publish(
    exchange='',
    routing_key='votes',
    body='{\"vote\":\"a\",\"voter_id\":\"test-dr\"}'
)
print('OK')
"

# Або через RabbitMQ admin:
kubectl exec -n voting-app rabbitmq-server-0 -- rabbitmqadmin \
  -u voting-app -p '$(kubectl get secret -n voting-app rabbitmq-default-user -o jsonpath="{.data.password}" | base64 -d)' \
  publish exchange=amq.default routing_key=votes \
  payload='{"vote":"a","voter_id":"test-dr"}' \
  properties='{"delivery_mode":2}'

# Перевірити що воркер обробив:
sleep 10
kubectl exec -n voting-app pg-vote-1 -- psql -U postgres -d db -c "SELECT * FROM votes;"
# → має бути хоча б один рядок
```

### 7.9 CI/CD

```bash
gh workflow run "🚀 Deploy voting-app" \
  --repo mochthebest-byte/my-devops-project \
  --field service=all --field environment=dev
```

Переконатись що build → push → sign проходять успішно.

---

## Файли які НЕ потребують змін (вже динамічні)

Ці файли використовують `{{ .Values.global.awsAccountId }}` або `data.aws_caller_identity` —
вони автоматично підхоплять новий Account ID після Phase 1.1.

### Helm templates (отримують accountId з `charts/argocd-apps/values.yaml`)

| Файл | Використання |
|---|---|
| `charts/argocd-apps/templates/velero.yaml` | `role-arn: arn:aws:iam::{{ .Values.global.awsAccountId }}:role/...` |
| `charts/argocd-apps/templates/karpenter.yaml` | `role-arn: arn:aws:iam::{{ .Values.global.awsAccountId }}:role/...` |
| `charts/argocd-apps/templates/argocd-image-updater.yaml` | `role-arn: arn:aws:iam::{{ .Values.global.awsAccountId }}:role/...` |
| `charts/gateway-config/templates/loadbalancer-config.yaml` | ACM ARN з `awsAccountId` + `awsRegion` |
| `charts/cnpg-clusters/templates/_helpers.tpl` | Backup bucket `{{ .backup.bucketPrefix }}-{{ .awsAccountId }}` |
| `charts/argo-rollout-vote/templates/rollout.yaml` | ECR image URL з `awsAccountId.dkr.ecr...` |
| `voting-app-vote/charts/vote/templates/deployment.yaml` | ECR image URL |
| `voting-app-result/charts/result/templates/deployment.yaml` | ECR image URL |
| `voting-app-worker/charts/worker/templates/deployment.yaml` | ECR image URL |

### Terraform (використовують `data.aws_caller_identity`)

| Файл | Використання |
|---|---|
| `infra-aws/velero.tf` | `data.aws_caller_identity.current.account_id` |
| `infra-aws/eks.tf` | `data.aws_caller_identity.current.account_id` |
| `infra-aws/outputs.tf` | `data.aws_caller_identity.current.account_id` |
| `infra-aws/ecr.tf` | ECR repository policy (динамічний principal) |

### GitHub Actions

| Файл | Механізм |
|---|---|
| `.github/workflows/deploy-voting-app.yml:97` | `${{ vars.AWS_ACCOUNT_ID }}` (треба встановити в Phase 0.2) |

### Vault / VSO (не потребують змін)

| Файл | Механізм |
|---|---|
| `charts/vault-init/templates/job.yaml` | Підключається до CNPG через `pg-vote-app` secret — не містить account ID |
| `charts/vso-config/templates/vault-dynamic-secret.yaml` | Звертається до Vault через ClusterIP — не містить account ID |
| `charts/vso-config/templates/vault-connection.yaml` | `vault.vault.svc.cluster.local:8200` — внутрішній DNS |
| `charts/vault-init/values.yaml` | Всі параметри відносні (host, namespace, clusterName) |

### Helm charts (не потребують змін)

| Файл | Механізм |
|---|---|
| `charts/loki-tempo/values.yaml` | Внутрішні S3 endpoint, бакет формується динамічно |
| `charts/grafana-datasources/values.yaml` | Loki/Tempo внутрішні URL (ClusterIP) |
| `charts/rabbitmq/values.yaml` | Відсутні account ID або зовнішні домени |
| `charts/infra-bootstrap/values.yaml` | Namespaces + RBAC — без зовнішніх референсів |

> ⚠️ **Важливо:** Всі перелічені файли НЕ потребують змін, але після ArgoCD sync варто перевірити що вони працюють коректно.

---

## Чекліст (одним рядком)

> [!NOTE]
> **Порядок:** Оновити код → GitHub variable + secrets → bootstrap-backend → terraform init → terraform apply → DNS (NS records) → ECR seed images → оновити EKS endpoint + ACM ID → ArgoCD → Vault → перевірка

```text
□ 0.1  Account ID отримано
□ 0.2  gh variable set AWS_ACCOUNT_ID
□ 0.3  gh secret set GITOPS_PAT (якщо потрібен)
□ 0.4  AWS CLI налаштовано на новий акаунт
□ —————————————————— Phase 1 ——————————————————
□ 1.1  charts/argocd-apps/values.yaml: awsAccountId
□ 1.2  charts/karpenter-resources/values.yaml: awsAccountId
□ 1.3  infra-aws/backend.hcl: bucket name
□ 1.4  infra-aws/terraform.tfvars: eks_public_access_cidrs (ваш IP)
□ 1.5  charts/gateway-config/values.yaml: acmCertificateId (після apply)
□ 1.6  charts/argocd-apps/values.yaml: clusterEndpoint (після apply)
□ 1.7  infra-aws/terraform.tfvars: node group sizing (desired=5, min=3, max=10)
□ 1.8  GitHub org (якщо змінюється): 18× ArgoCD templates + root-app + workflows + variables.tf
□ 1.9  Domain (якщо змінюється): tfvars, variables.tf, budget.tf, gateway-config (8×),
          monitoring-values.yaml, keycloak values.yaml, cert-manager cluster-issuers,
          argo-rollout-vote analysis-template.yaml
□ 1.10  commit + push
□ —————————————————— Phase 2 ——————————————————
□ 2.1  scripts/bootstrap-backend.sh
□ 2.2  terraform init -reconfigure
□ —————————————————— Phase 3 ——————————————————
□ 3.1  terraform plan
□ 3.2  terraform apply (~30 хв)
□ 3.3  DNS nameservers оновлено в реєстратора
□ —————————————————— Phase 4 ——————————————————
□ 4.1  ACM cert ID оновлено в gateway-config/values.yaml
□ 4.2  EKS endpoint оновлено в argocd-apps/values.yaml
□ 4.3  commit + push
□ —————————————————— Phase 5 ——————————————————
□ 5.1  GitHub OIDC працює
□ 5.2  Перші образи зібрано та запушено в ECR вручну
□ 5.3  CI/CD pipeline пропрацював
□ 5.4  Образи є в ECR (describe-images)
□ —————————————————— Phase 6 ——————————————————
□ 6.1  ArgoCD встановлено в кластер
□ 6.2  root-app.yaml applied
□ 6.3  ArgoCD sync — всі 18 додатків Healthy
□ 6.4  Route53 DNS records створено (external-dns)
□ 6.5  Vault ініціалізовано та розпечатано (vault-init)
□ 6.6  VSO створив pg-vote-dynamic secret
□ 6.7  Keycloak працює і accessible
□ 6.8  Grafana запущена (чекає SSO або local admin)
□ —————————————————— Phase 7 ——————————————————
□ 7.1  Поди Running (крім Completed)
□ 7.2  Ендпоінти відповідають 200 (vote, result, argocd, grafana, keycloak)
□ 7.3  Всі ArgoCD додатки Healthy
□ 7.4  Dynamic DB secret від VSO працює
□ 7.5  Vault статус OK
□ 7.6  Keycloak admin пароль отримано
□ 7.7  Grafana працює (SSO або local)
□ 7.8  Голосування працює (через RabbitMQ → worker → PostgreSQL)
□ 7.9  CI/CD працює (build → push → sign)
```
