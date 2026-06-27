# Infrastructure as Code — Terraform

AWS infrastructure for the voting-app EKS cluster, managed via Terraform.

## Resources

| Module | Source | Purpose |
|--------|--------|---------|
| `vpc` | `terraform-aws-modules/vpc/aws` (~> 5.0) | VPC with public/private subnets, NAT gateway |
| `eks` | `terraform-aws-modules/eks/aws` (~> 20.0) | EKS cluster with managed node groups |
| `app_sg` | `./modules/app-sg` | Custom application security group (власний модуль) |

## Other Resources

| File | Resource | Purpose |
|------|----------|---------|
| `ecr.tf` | `aws_ecr_repository` × 3 | ECR for vote/result/worker images |
| `dns.tf` | Route53 zone + ACM cert | DNS for `mochthebest.pp.ua`, wildcard HTTPS cert |
| `budget.tf` | `aws_budgets_budget` | $50/month alert at 80% and 100% |
| `secrets.tf` | Secrets Manager + random password | `/my-app/grafana-oidc` for OIDC client secret |

## IAM / OIDC

| Resource | Purpose | Managed by |
|----------|---------|-----------|
| `github-oidc` | OIDC identity provider for GitHub Actions (`token.actions.githubusercontent.com`) | Terraform (`github-oidc.tf`, opt-in via `create_github_oidc = true`) |
| `my-app-eks-github-ci` | IAM role assumed by GitHub Actions via OIDC | Terraform (`github-oidc.tf`, opt-in) |
| `my-app-eks-eso` | IAM role for External Secrets Operator (IRSA) | `addons.tf` |
| `my-app-eks-lb-controller` | IAM role for AWS Load Balancer Controller | `addons.tf` |
| `my-app-eks-external-dns` | IAM role for ExternalDNS | `addons.tf` |

## Helm Releases (deployed via Terraform)

| Release | Chart | Namespace |
|---------|-------|-----------|
| `aws-load-balancer-controller` | eks-charts | `kube-system` |
| `external-dns` | kubernetes-sigs | `kube-system` |
| `cert-manager` | jetstack | `cert-manager` |
| `external-secrets` | external-secrets | `external-secrets` |

## Secrets

Secrets are stored in AWS Secrets Manager (not in Git):

| Secret Path | Purpose |
|-------------|---------|
| `/my-app/grafana-oidc` | Grafana OIDC client secret |
| `/my-app/keycloak-db` | Keycloak PostgreSQL password |

## State

- **Backend**: S3 (`my-terraform-state-bucket-1233` / `eu-north-1`)
- **Locking**: DynamoDB (via S3 lock file)

## Usage

```bash
cd infra-aws
terraform init
terraform plan
terraform apply

# Get the CI role ARN for GitHub Actions
terraform output github_ci_role_arn
```
