# Infrastructure as Code — Terraform

AWS infrastructure for the voting-app EKS cluster, managed via Terraform.

## Resources

| Module | Source | Purpose |
|--------|--------|---------|
| `vpc` | `terraform-aws-modules/vpc/aws` (~> 5.0) | VPC with public/private subnets, NAT gateway |
| `eks` | `terraform-aws-modules/eks/aws` (~> 20.0) | EKS cluster with managed node groups |
| `my_app_sg` | `./modules/my-app-sg` | Custom application security group |

## IAM / OIDC

| Resource | Purpose |
|----------|---------|
| `github-oidc` | OIDC identity provider for GitHub Actions (`token.actions.githubusercontent.com`) |
| `my-app-eks-github-ci` | IAM role assumed by GitHub Actions via OIDC |
| `my-app-eks-eso` | IAM role for External Secrets Operator (IRSA) |
| `my-app-eks-lb-controller` | IAM role for AWS Load Balancer Controller |
| `my-app-eks-external-dns` | IAM role for ExternalDNS |

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
