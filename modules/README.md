# Terraform Modules — Library

Shared and reusable Terraform modules for the voting-app infrastructure.

## Active Modules

| Module | Location | Purpose |
|--------|----------|---------|
| `app-sg` | `infra-aws/modules/app-sg` | Custom security group for EKS workers (власний модуль) |

> **Note:** `my-app-sg` at root level was removed — it was an unused duplicate.
> Use `infra-aws/modules/app-sg` for EKS node security groups.
