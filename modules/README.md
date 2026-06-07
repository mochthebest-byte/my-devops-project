# Custom Terraform Modules

Reusable Terraform modules for the voting-app infrastructure.

## Available Modules

### `my-app-sg`

Security group module for application workloads.

**Usage:**

```hcl
module "my_app_sg" {
  source = "./modules/my-app-sg"
  vpc_id = module.vpc.vpc_id
  # ... variables
}
```

**Variables:** name, description, vpc_id, ingress_rules, egress_rules, tags
