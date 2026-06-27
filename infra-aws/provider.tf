provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

# kubectl provider видалено — не використовується жодним ресурсом.
# Всі K8s-операції виконуються через helm_release або ArgoCD.
