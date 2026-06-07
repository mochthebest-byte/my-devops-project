# Phase 10 — Налаштування Production-grade CI

## Архітектура

```
mochthebest-byte/voting-app          mochthebest-byte/ci-pipelines       AWS
┌─────────────────────┐              ┌────────────────────────┐      ┌────────────────┐
│ .github/workflows/  │              │ .github/workflows/     │      │ OIDC Provider  │
│   ci.yml            │──uses:main──▶│   reusable-build.yml   │──▶   │ (GitHub → AWS) │
│                     │              │                        │      └───────┬────────┘
│  push → main        │              │  1. checkout           │              │
│  matrix:            │              │  2. OIDC auth          │◀────sts:AssumeRole
│    vote             │              │  3. ecr login          │      ┌───────┴────────┐
│    result           │              │  4. buildx multi-arch  │      │ my-app-eks-    │
│    worker           │              │  5. push to ECR        │      │ github-ci      │
│                     │              │  6. update GitOps repo │      └────────────────┘
└─────────────────────┘              └───────────┬────────────┘
                                                  │ push new image tag
                                                  ▼
                                        mochthebest-byte/gitops
                                              (GitOps repo)
                                                  │
                                                  ▼ (ArgoCD auto-sync)
                                               EKS cluster
```

## 1. Що створить Terraform

Після `terraform apply` в `infra-aws/`:

| Ресурс | Ім'я | Призначення |
|--------|------|-------------|
| OIDC Provider | `arn:aws:iam::...:oidc-provider/token.actions.githubusercontent.com` | Довіра до GitHub |
| IAM Role | `my-app-eks-github-ci` | Роль, яку assume GitHub Actions |
| IAM Policy | `my-app-eks-github-ci` | Права на ECR push/pull + EKS describe |
| ECR repo | `my-app/vote` | Docker registry для vote |
| ECR repo | `my-app/result` | Docker registry для result |
| ECR repo | `my-app/worker` | Docker registry для worker |

### Важливі параметри, які потрібно підставити

У `github-oidc.tf` знайдіть ці рядки і переконайтеся, що вони правильні:

```
# рядок 74–78: список репозиторіїв, яким дозволено використовувати роль
condition {
  variable = "token.actions.githubusercontent.com:sub"
  values   = [
    "repo:mochthebest-byte/voting-app:*",
    "repo:mochthebest-byte/worker:*",
    "repo:mochthebest-byte/ci-pipelines:*",
  ]
}
```

> **Важливо:** Формат `repo:<owner>/<repo>:*` — `:*` означає "будь-яка гілка".
> Для посилення безпеки можна вказати `:ref:refs/heads/main` — тільки main гілка.
> Див. [GitHub OIDC docs](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect).

## 2. Яку роль вказати в GitHub Actions

Після `terraform apply` виконайте:

```bash
cd infra-aws/
terraform output github_ci_role_arn
```

Ви отримаєте ARN типу:
```
arn:aws:iam::428156589409:role/my-app-eks-github-ci
```

Це значення підставляється в `ci.yml` сервісного репозиторію:

```yaml
jobs:
  build-and-deploy:
    uses: mochthebest-byte/ci-pipelines/.github/workflows/reusable-build.yml@main
    with:
      aws_region: us-east-1
      ci_role_arn: arn:aws:iam::428156589409:role/my-app-eks-github-ci   # ← сюди
      # ...
```

## 3. Налаштування сервісного репозиторію

### Крок 1: Додати файл `.github/workflows/ci.yml`

Скопіюйте [`ci-pipelines/service-workflow-example.yml`](./service-workflow-example.yml) у ваш сервісний репозиторій:

```bash
# У вашому voting-app репозиторії:
mkdir -p .github/workflows
# Скопіюйте вміст service-workflow-example.yml у .github/workflows/ci.yml
```

### Крок 2: Додати секрет `GITOPS_PAT`

```bash
gh secret set GITOPS_PAT --repo mochthebest-byte/voting-app --body "github_pat_..."
```

Токен має права `contents: write` на GitOps репозиторій (`mochthebest-byte/gitops`).

### Крок 3: Переконатися, що GitOps має правильні маніфести

CI оновлює `image.tag` у файлах:
- `apps/vote/values.yaml`
- `apps/result/values.yaml`
- `apps/worker/values.yaml`

Вони мають існувати в `mochthebest-byte/gitops` і містити:

```yaml
image:
  repository: 428156589409.dkr.ecr.us-east-1.amazonaws.com/my-app/vote
  tag: latest    # ← CI оновлює цей рядок
```

## 4. ECR очищення

Автоматично:
- **Тримаємо** останні 10 образів
- **Видаляємо** образи старші 90 днів
- **Scan on push** — автоматичне сканування на вразливості

## 5. Перевірка

Після налаштування зробіть push у `main` сервісного репозиторію:

```bash
git commit --allow-empty -m "test: trigger CI" && git push
```

Перейдіть в GitHub Actions вашого репозиторію — має запуститись workflow:

```
CI — Build & Deploy
├── test (Trivy scan)
└── build-and-deploy (matrix: vote, result, worker)
    └── викликає mochthebest-byte/ci-pipelines/reusable-build.yml
```

## 6. Troubleshooting

| Проблема | Причина | Рішення |
|----------|---------|---------|
| `Error: Not authorized to perform sts:AssumeRoleWithWebIdentity` | OIDC trust policy не включає ваш репозиторій | Додайте `repo:mochthebest-byte/<repo>:*` до `github-oidc.tf` |
| `Error: RequestError: no ECR repository` | Репозиторій не створено | Запустіть `terraform apply` в `infra-aws/` |
| `Error: Manifest not found: apps/vote/values.yaml` | GitOps репозиторій не має очікуваної структури | Створіть файл або вкажіть `gitops_manifest_path` |
| `Cannot read property 'registry' of undefined` | build-and-push job не завершився | Перевірте логи build-and-push job |
