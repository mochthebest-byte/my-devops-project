# CI/CD Pipelines — Centralized Workflows

Reusable GitHub Actions workflows for the voting-app microservices.

## Architecture

```
Service Repo (voting-app)     ci-pipelines (this dir)         AWS
┌──────────────────┐          ┌───────────────────┐      ┌──────────┐
│  ci.yml          │──uses──▶ │  reusable-build   │──▶   │ OIDC     │
│  (matrix:        │          │  .yml              │      └────┬─────┘
│   vote,result,   │          │                    │           │
│   worker)        │          │  1. Checkout       │◀──sts:AssumeRole
│                  │          │  2. OIDC auth      │      ┌────┴─────┐
│                  │          │  3. ECR login       │      │ IAM Role │
│                  │          │  4. buildx amd64+arm64     └──────────┘
│                  │          │  5. Push to ECR     │
│                  │          │  6. Update GitOps   │
└──────────────────┘          └─────────┬───────────┘
                                        │
                                  GitOps Repo
                                        │
                                  ArgoCD Sync
                                        │
                                      EKS
```

## Files

| File | Purpose |
|------|---------|
| `reusable-build.yml` | Central reusable workflow (`on: workflow_call`) |
| `service-workflow-example.yml` | Template for service repos to call the reusable pipeline |
| `SETUP.md` | Full setup guide |

## Monorepo CI (Alternative)

The `my-devops-project` repo also has its own workflow at `.github/workflows/deploy-voting-app.yml` that:
- Checks out code directly from `mochthebest-byte/voting-app`
- Uses OIDC to authenticate to AWS
- Builds multi-arch Docker images
- Updates the GitOps repo

This is the recommended approach — all builds visible in a single repo.

## Required Secrets

| Secret | Used By | Purpose |
|--------|---------|---------|
| `GITOPS_PAT` | All workflows | GitHub token with push access to the GitOps repo |

## Troubleshooting

| Issue | Likely Cause | Fix |
|-------|-------------|-----|
| `startup_failure` | Workflow YAML syntax | Validate YAML locally before pushing |
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | Repo not in OIDC trust policy | Add repo to `github-oidc.tf` |
| `Manifest not found` | GitOps repo doesn't have expected file | Create the manifest or set `gitops_manifest_path` |
