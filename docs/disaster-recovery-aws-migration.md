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

### 1.3 ACM certificate (новий в новому акаунті)

Після `terraform apply` отримати новий cert ID:

```bash
terraform output acm_certificate_arn
# → arn:aws:acm:eu-central-1:<NEW_ACCOUNT_ID>:certificate/NEW-UUID-HERE
```

| № | Файл | Зміна |
|---|---|---|
| 4 | `charts/gateway-config/values.yaml:25` | `acmCertificateId: "NEW-UUID-HERE"` |

### 1.4 EKS cluster endpoint

Після створення EKS:

```bash
terraform output cluster_endpoint
# → https://XXXXXX.gr7.eu-central-1.eks.amazonaws.com
```

| № | Файл | Зміна |
|---|---|---|
| 5 | `charts/argocd-apps/values.yaml:19` | `clusterEndpoint: "https://XXXXXX.gr7.eu-central-1.eks.amazonaws.com"` |

### 1.5 GitHub org (якщо змінюється)

| № | Файл | Зміна |
|---|---|---|
| 6 | `infra-aws/variables.tf:97` | `default = ["new-org/my-devops-project", "new-org/voting-app"]` |
| 7 | `.github/workflows/deploy-voting-app.yml:40` | `--repo new-org/my-devops-project` |
| 8 | `.github/workflows/deploy-voting-app.yml:43` | `GITOPS_REPO: new-org/gitops` |
| 9 | `.github/workflows/deploy-voting-app.yml:88` | `repository: new-org/voting-app` |
| 10 | `root-app.yaml:9` | `repoURL: https://github.com/new-org/my-devops-project.git` |
| 11 | `charts/root-app/templates/root-app.yaml:9` | `repoURL: https://github.com/new-org/my-devops-project.git` |
| 12 | **18×** `charts/argocd-apps/templates/*.yaml:11` | `repoURL: https://github.com/new-org/my-devops-project.git` |

> Список усіх 18 ArgoCD Application template файлів:
> `cert-manager-issuers.yaml`, `cnpg-clusters.yaml`, `gateway-config.yaml`,
> `infra-bootstrap.yaml`, `karpenter.yaml`, `karpenter-resources.yaml`,
> `keycloak.yaml`, `kyverno-policies.yaml`, `loki-tempo.yaml`,
> `rabbitmq.yaml`, `rabbitmq-operator.yaml`, `result.yaml`,
> `argo-rollout-vote.yaml`, `vault-init.yaml`, `vault-vote-secrets.yaml`,
> `voting-app.yaml`, `vso-config.yaml`, `worker.yaml`

### 1.6 Domain (якщо змінюється)

Пошук `mochthebest.pp.ua` → замінити на новий домен у всіх файлах нижче.

**Terraform:**

| № | Файл | Зміна |
|---|---|---|
| 13 | `infra-aws/terraform.tfvars:18` | `domain_name = "new-domain.com"` |
| 14 | `infra-aws/variables.tf:64` (default) | `default = "new-domain.com"` |
| 15 | `infra-aws/budget.tf:23,31` | `admin@new-domain.com` (2 місця) |

**Gateway routes (8 значень в одному файлі):**

| № | Файл | Зміна |
|---|---|---|
| 16 | `charts/gateway-config/values.yaml:16` | `domain: new-domain.com` |
| 17 | `charts/gateway-config/values.yaml:46` | `"vote.new-domain.com"` |
| 18 | `charts/gateway-config/values.yaml:55` | `"result.new-domain.com"` |
| 19 | `charts/gateway-config/values.yaml:64` | `"grafana.new-domain.com"` |
| 20 | `charts/gateway-config/values.yaml:73` | `"keycloak.new-domain.com"` |
| 21 | `charts/gateway-config/values.yaml:82` | `"argocd.new-domain.com"` |
| 22 | `charts/gateway-config/values.yaml:91` | `"rollouts.new-domain.com"` |

**Monitoring / Keycloak / Cert Manager:**

| № | Файл | Зміна |
|---|---|---|
| 23 | `monitoring-values.yaml:37-46` | 5× Grafana OIDC URLs з новим доменом |
| 24 | `keycloak/charts/keycloak/values.yaml:55` | `hostname: keycloak.new-domain.com` |
| 25 | `keycloak/charts/keycloak/values.yaml:130` | Grafana redirect URI |
| 26 | `charts/cert-manager-issuers/templates/cluster-issuers.yaml:15` | `email: admin@new-domain.com` |

**Argo Rollout аналіз (Prometheus metric labels):**

| № | Файл | Зміна |
|---|---|---|
| 27 | `charts/argo-rollout-vote/templates/analysis-template.yaml:18-19` | `host="vote.new-domain.com"` (2 місця) |

### 1.7 Commit

```bash
git add -A
git commit -m "chore: migrate AWS account <OLD> → <NEW>"
git push
```

> **⏱ Оцінка:** ~10-20 хв на пошук+заміну (sed або глобальний find-and-replace).

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
- **S3 buckets**: Velero backups (`voting-app-velero-backups-<ID>`), ALB logs, EKS cluster autoscaler
- **IAM roles**: GitHub CI OIDC, Karpenter controller, Velero, Cluster Autoscaler, EBS CSI driver, ArgoCD Image Updater
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
```

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

### 5.2 Перевірити ручним workflow

В GitHub Actions:
- `Actions` → `🚀 Deploy voting-app` → `Run workflow`
- Вибрати `dev` + `vote` → `Run`

Переконатись що:
- OIDC auth проходить (role-to-assume з `vars.AWS_ACCOUNT_ID`)
- Docker образ збирається та пушиться в новий ECR
- Cosign signing + SBOM attestation проходять

### 5.3 Запушити перші образи в ECR (якщо пусто)

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

> ⚠️ Якщо якісь додатки `OutOfSync` — це нормально після першого деплою.
> Запустити `argocd sync --all --prune` ще раз.

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

---

## Чекліст (одним рядком)

> [!NOTE]
> **Порядок:** Оновити код → GitHub variable → bootstrap-backend → terraform init → terraform apply → DNS (NS records) → оновити EKS endpoint + ACM ID → ArgoCD → перевірка

```text
□ 0.1  Account ID отримано
□ 0.2  gh variable set AWS_ACCOUNT_ID
□ 0.3  AWS CLI налаштовано на новий акаунт
□ —————————————————— Phase 1 ——————————————————
□ 1.1  charts/argocd-apps/values.yaml: awsAccountId
□ 1.2  charts/karpenter-resources/values.yaml: awsAccountId
□ 1.3  infra-aws/backend.hcl: bucket name
□ 1.4  charts/gateway-config/values.yaml: acmCertificateId (після apply)
□ 1.5  charts/argocd-apps/values.yaml: clusterEndpoint (після apply)
□ 1.6  GitHub org (якщо змінюється): 18× ArgoCD templates + root-app + workflows + variables.tf
□ 1.7  Domain (якщо змінюється): tfvars, variables.tf, budget.tf, gateway-config (8×),
          monitoring-values.yaml, keycloak values.yaml, cert-manager cluster-issuers,
          argo-rollout-vote analysis-template.yaml
□ 1.8  commit + push
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
□ 5.2  Перші образи запушились в ECR
□ —————————————————— Phase 6 ——————————————————
□ 6.1  ArgoCD встановлено в кластер
□ 6.2  root-app.yaml applied
□ 6.3  ArgoCD sync — всі 18 додатків Healthy
□ 6.4  Route53 DNS records створено (external-dns)
□ —————————————————— Phase 7 ——————————————————
□ 7.1  Ендпоінти відповідають 200 (vote, result, argocd, grafana, keycloak)
□ 7.2  Всі ArgoCD додатки Healthy
□ 7.3  Всі поди Running/Completed
□ 7.4  Голосування працює (POST + GET result)
□ 7.5  CI/CD працює (build → push → sign)
```
