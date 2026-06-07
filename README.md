# My DevOps Project

Infrastructure-as-Code, CI/CD pipelines, and Kubernetes deployment for the voting-app microservices stack.

## Architecture Overview

```
                    my-devops-project (this repo)
                    ├── .github/workflows/
                    │   └── deploy-voting-app.yml    # Central CI/CD (monorepo-style)
                    ├── ci-pipelines/                # Reusable GitHub Actions workflows
                    │   ├── reusable-build.yml       # Build + ECR + GitOps pipeline
                    │   └── service-workflow-example.yml  # Template for service repos
                    ├── infra-aws/                   # Terraform (VPC, EKS, OIDC, ECR)
                    ├── k8s/                         # Gateway API, cert-manager, ESO manifests
                    ├── keycloak/                    # Keycloak Helm chart (OIDC provider)
                    ├── argocd-apps/                 # ArgoCD App-of-Apps definitions
                    ├── voting-app-vote/             # Vote service (Python/Flask)
                    ├── voting-app-result/           # Result service (Node.js)
                    └── voting-app-worker/           # Worker service (.NET)
```

## CI/CD Flow

```mermaid
graph LR
    A[Developer Push] --> B[GitHub Actions]
    B --> C[OIDC Auth to AWS]
    B --> D[Buildx Multi-Arch]
    D --> E[ECR Repository]
    B --> F[GitOps Commit]
    F --> G[ArgoCD Sync]
    G --> H[EKS Cluster]
```

- **OIDC**: No static AWS keys — temporary credentials via GitHub OIDC token
- **Multi-arch**: Docker images built for both `linux/amd64` and `linux/arm64`
- **GitOps**: CI updates image tags in a GitOps repo, ArgoCD auto-syncs to EKS
- **Monorepo CI**: All builds visible in this repo's Actions tab

## Components

| Directory | Purpose | Tech Stack |
|-----------|---------|------------|
| `infra-aws/` | AWS infrastructure | Terraform (VPC, EKS, ECR, IAM, Secrets Manager) |
| `ci-pipelines/` | Centralized CI/CD | GitHub Actions reusable workflows |
| `k8s/` | Kubernetes infrastructure config | Gateway API, cert-manager, External Secrets |
| `keycloak/` | SSO / OIDC provider | Keycloak Helm chart |
| `argocd-apps/` | Application definitions | ArgoCD App-of-Apps |
| `voting-app-*/` | Microservice source code | Python / Node.js / .NET |

## Prerequisites

- AWS account with CLI configured
- Terraform >= 1.5
- kubectl, kind (for local dev)
- GitHub CLI (`gh`)

## Quick Start

```bash
# 1. Deploy infrastructure
cd infra-aws
terraform init && terraform apply

# 2. Get CI role ARN
terraform output github_ci_role_arn

# 3. Push code to trigger CI
git push origin main
# Then go to: https://github.com/mochthebest-byte/my-devops-project/actions

# Or trigger manually:
gh workflow run deploy-voting-app.yml -f service=all -f environment=dev
```
