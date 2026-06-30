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

### 0.3 Налаштувати AWS CLI для нового акаунта

```bash
aws configure sso  # або aws configure --profile new-account
export AWS_PROFILE=new-account
```

---

## Phase 1 — Оновити код (commit в Git)

### 1.1 Account ID — 2 файли

| Файл | Зміна |
|---|---|
| `charts/argocd-apps/values.yaml:14` | `awsAccountId: "<NEW_ACCOUNT_ID>"` |
| `charts/karpenter-resources/values.yaml:7` | `awsAccountId: "<NEW_ACCOUNT_ID>"` |

### 1.2 Terraform state backend

| Файл | Зміна |
|---|---|
| `infra-aws/backend.hcl:12` | `bucket = "voting-app-tfstate-<NEW_ACCOUNT_ID>"` |

### 1.3 ACM certificate (новий в новому акаунті)

Після `terraform apply` отримати новий cert ID:

```bash
terraform output acm_certificate_arn
# → arn:aws:acm:eu-central-1:<NEW_ACCOUNT_ID>:certificate/NEW-UUID-HERE
```

| Файл | Зміна |
|---|---|
| `charts/gateway-config/values.yaml:25` | `acmCertificateId: "NEW-UUID-HERE"` |

### 1.4 EKS cluster endpoint

Після створення EKS:

```bash
terraform output cluster_endpoint
# → https://XXXXXX.gr7.eu-central-1.eks.amazonaws.com
```

| Файл | Зміна |
|---|---|
| `charts/argocd-apps/values.yaml:19` | `clusterEndpoint: "https://XXXXXX.gr7.eu-central-1.eks.amazonaws.com"` |

### 1.5 GitHub org (якщо змінюється)

| Файл | Зміна |
|---|---|
| `infra-aws/variables.tf:97` | `default = ["new-org/my-devops-project", "new-org/voting-app"]` |
| `.github/workflows/deploy-voting-app.yml:43` | `GITOPS_REPO: new-org/gitops` |
| `.github/workflows/deploy-voting-app.yml:88` | `repository: new-org/voting-app` |
| `root-app.yaml:9` | `repoURL: https://github.com/new-org/my-devops-project.git` |

### 1.6 Domain (якщо змінюється)

Domains хардкодом в ~15 файлах — шукати `mochthebest.pp.ua` → замінити на новий.

Ключові:
- `infra-aws/terraform.tfvars:18` — `domain_name`
- `charts/gateway-config/values.yaml` — hostname в кожному route
- `charts/cert-manager-issuers/templates/cluster-issuers.yaml` — email
- `monitoring-values.yaml` — Grafana OIDC URLs
- `keycloak/charts/keycloak/values.yaml` — Keycloak redirect URIs

### 1.7 Commit

```bash
git add -A
git commit -m "chore: migrate AWS account <OLD> → <NEW>"
git push
```

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

Очікується ~200+ ресурсів to create, 0 to change/destroy.
**ВАЖЛИВО:** Переконатись що не намагається видалити старі ресурси — їх немає в новому акаунті, це нормально.

### 3.2 Застосувати

```bash
terraform apply tf.plan
```

Тривалість: ~25-35 хв (EKS + ALB + ACM validation — найдовше).

Після apply перевірити ключові ресурси:

```bash
terraform output aws_account_id         # → <NEW_ACCOUNT_ID>
terraform output cluster_endpoint       # → https://...
terraform output acm_certificate_arn    # → arn:aws:acm:...
terraform output github_ci_role_arn     # → arn:aws:iam::...
terraform output dns_nameservers        # → ns-xxx.awsdns-xx.net
```

### 3.3 Оновити DNS у реєстратора

Nameservers з `terraform output dns_nameservers` вказати в панелі реєстратора
(наприклад, NIC.UA, Namecheap, Route53, тощо).

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

### 5.2 Перевірити ручним workflow

В GitHub Actions:
- `Actions` → `🚀 Deploy voting-app` → `Run workflow`
- Вибрати `dev` + `vote` → `Run`

Переконатись що OIDC auth проходить і образ збирається.

---

## Phase 6 — ArgoCD bootstrap

### 6.1 Встановити ArgoCD в кластер

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### 6.2 Додати root-додаток

```bash
kubectl apply -f root-app.yaml
```

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
```

---

## Phase 7 — Перевірка (контрольний тест)

### 7.1 Ендпоінти

```bash
curl -sI https://vote.mochthebest.pp.ua    # 200
curl -sI https://result.mochthebest.pp.ua  # 200
curl -sI https://argocd.mochthebest.pp.ua  # 200
curl -sI https://grafana.mochthebest.pp.ua # 200
curl -sI https://keycloak.mochthebest.pp.ua # 200
```

### 7.2 ArgoCD — всі Healthy

```bash
argocd app list | grep -v Healthy
# → порожньо (все Healthy)
```

### 7.3 Працюючі поди

```bash
kubectl get pods -A | grep -v Running | grep -v Completed
# → порожньо (все Running/Completed)
```

### 7.4 Перевірка голосування

```bash
# За голосувати:
curl -X POST https://vote.mochthebest.pp.ua/ -d 'vote=a'
# Перевірити результат:
curl -s https://result.mochthebest.pp.ua/ | grep -q 'Votes'
echo "OK"
```

### 7.5 CI/CD

```bash
gh workflow run "🚀 Deploy voting-app" \
  --repo mochthebest-byte/my-devops-project \
  --field service=all --field environment=dev
```

---

## Файли які НЕ потребують змін (вже динамічні)

| Файл | Механізм |
|---|---|
| `infra-aws/velero.tf:7` | `data.aws_caller_identity.current.account_id` |
| `infra-aws/eks.tf:44` | `data.aws_caller_identity.current.account_id` |
| `infra-aws/outputs.tf` | `data.aws_caller_identity.current.account_id` |
| `charts/argocd-apps/templates/velero.yaml` | `{{ .Values.global.awsAccountId }}` |
| `charts/gateway-config/templates/loadbalancer-config.yaml` | `{{ .Values.global.awsAccountId }}` |
| `.github/workflows/deploy-voting-app.yml:97` | `${{ vars.AWS_ACCOUNT_ID }}` |
| `voting-app-*/charts/*/deployment.yaml` | `{{ .Values.global.awsAccountId }}` |

---

## Чеклист (одним рядком)

> [!NOTE]
> **Порядок:** Оновити код → GitHub variable → bootstrap-backend → terraform init → terraform apply → DNS (NS records) → оновити EKS endpoint + ACM ID → ArgoCD → перевірка

```text
□ 0.1  Account ID отримано
□ 0.2  gh variable set AWS_ACCOUNT_ID
□ 0.3  AWS CLI налаштовано на новий акаунт
□ 1.1  charts/argocd-apps/values.yaml: awsAccountId
□ 1.2  charts/karpenter-resources/values.yaml: awsAccountId
□ 1.3  infra-aws/backend.hcl: bucket name
□ 1.7  commit + push
□ 2.1  scripts/bootstrap-backend.sh
□ 2.2  terraform init -reconfigure
□ 3.1  terraform plan
□ 3.2  terraform apply
□ 3.3  DNS nameservers оновлено в реєстратора
□ 4.1  ACM cert ID оновлено
□ 4.2  EKS endpoint оновлено
□ 4.3  commit + push
□ 5.1  GitHub OIDC працює
□ 6.1  ArgoCD встановлено
□ 6.2  root-app.yaml applied
□ 7.1  Ендпоінти відповідають 200
□ 7.2  Всі ArgoCD додатки Healthy
□ 7.3  Всі поди Running
□ 7.4  Голосування працює
□ 7.5  CI/CD працює
```
