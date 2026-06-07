# Phase 10 — Production CI Setup Guide

## Architecture

```
mochthebest-byte/voting-app          mochthebest-byte/ci-pipelines       AWS
┌─────────────────────┐              ┌────────────────────────┐      ┌────────────────┐
│ .github/workflows/  │              │ .github/workflows/     │      │ OIDC Provider  │
│   ci.yml            │──uses:main──▶│   reusable-build.yml   │──▶   │ (GitHub→AWS)   │
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

## 1. What Terraform Creates

After `terraform apply` in `infra-aws/`:

| Resource | Name | Purpose |
|----------|------|---------|
| OIDC Provider | `arn:aws:iam::...:oidc-provider/token.actions.githubusercontent.com` | GitHub trust |
| IAM Role | `my-app-eks-github-ci` | Role assumed by GitHub Actions |
| IAM Policy | `my-app-eks-github-ci` | ECR push/pull + EKS describe |
| ECR repo | `my-app/vote` | Docker registry for vote |
| ECR repo | `my-app/result` | Docker registry for result |
| ECR repo | `my-app/worker` | Docker registry for worker |

### Key parameters to check

In `github-oidc.tf`, find the trust policy and ensure your repos are listed:

```
condition {
  variable = "token.actions.githubusercontent.com:sub"
  values   = [
    "repo:mochthebest-byte/voting-app:*",
    "repo:mochthebest-byte/worker:*",
    "repo:mochthebest-byte/ci-pipelines:*",
    "repo:mochthebest-byte/my-devops-project:*",
  ]
}
```

> **Important:** Format is `repo:<owner>/<repo>:*` — `:*` means "any branch".
> For tighter security, use `:ref:refs/heads/main` (main branch only).
> See [GitHub OIDC docs](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect).

## 2. Role ARN for GitHub Actions

After `terraform apply`:

```bash
cd infra-aws/
terraform output github_ci_role_arn
```

Output example:
```
arn:aws:iam::428156589409:role/my-app-eks-github-ci
```

Use this as `ci_role_arn` in your workflow.

## 3. Setting Up a Service Repository

### Step 1: Add `.github/workflows/ci.yml`

Copy [`ci-pipelines/service-workflow-example.yml`](./service-workflow-example.yml) to your service repo:

```bash
# In your voting-app repo:
mkdir -p .github/workflows
# Copy the content of service-workflow-example.yml into .github/workflows/ci.yml
```

### Step 2: Add the `GITOPS_PAT` secret

```bash
gh secret set GITOPS_PAT --repo mochthebest-byte/voting-app --body "github_pat_..."
```

The token needs `contents: write` access on the GitOps repo (`mochthebest-byte/gitops`).

### Step 3: Verify GitOps manifests exist

CI updates the `image.tag` in:
- `apps/vote/values.yaml`
- `apps/result/values.yaml`
- `apps/worker/values.yaml`

These must exist in `mochthebest-byte/gitops` and contain:

```yaml
image:
  repository: 428156589409.dkr.ecr.us-east-1.amazonaws.com/my-app/vote
  tag: latest    # ← CI updates this line
```

## 4. Monorepo CI (Alternative)

Instead of per-repo CI, use the central workflow in `my-devops-project`:

```
https://github.com/mochthebest-byte/my-devops-project/actions/workflows/deploy-voting-app.yml
```

Trigger manually:
```bash
gh workflow run deploy-voting-app.yml -f service=all -f environment=dev
```

This workflow:
- Clones voting-app code from its repository
- Uses OIDC auth (same IAM role)
- Builds multi-arch Docker images
- Updates GitOps

## 5. ECR Cleanup

Automatic:
- **Keep** last 10 images
- **Expire** images older than 90 days (untagged only)
- **Scan on push** — vulnerability scanning

## 6. Verification

After setup, make a push to `main`:

```bash
git commit --allow-empty -m "test: trigger CI" && git push
```

Check GitHub Actions:
```
CI - Build & Deploy
├── test (Trivy scan)
└── build-and-deploy (matrix: vote, result, worker)
    └── calls mochthebest-byte/ci-pipelines/reusable-build.yml
```

## 7. Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | OIDC trust policy doesn't include your repo | Add `repo:org/<repo>:*` to `github-oidc.tf` |
| `No ECR repository found` | Repository doesn't exist | Run `terraform apply` in `infra-aws/` |
| `Manifest not found: apps/vote/values.yaml` | GitOps repo missing expected structure | Create the file or set `gitops_manifest_path` |
| `startup_failure` | Workflow YAML syntax error | Validate YAML locally before pushing |
