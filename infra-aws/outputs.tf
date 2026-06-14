output "cluster_name" {
  description = "EKS Cluster Name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API Endpoint"
  value       = module.eks.cluster_endpoint
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "node_security_group_id" {
  description = "Node Security Group ID"
  value       = module.app_sg.node_security_group_id
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "alb_dns" {
  description = "ALB DNS name (after gateway is created)"
  value       = "Run: kubectl get gateway -n voting-app voting-app-gateway -o jsonpath='{.status.addresses[0].value}'"
}

# ─── ECR ──────────────────────────────────────────────
output "ecr_repositories" {
  description = "ECR repository URLs"
  value = {
    for name, repo in aws_ecr_repository.this : name => repo.repository_url
  }
}

# ─── DNS ────────────────────────────────────────────────
output "dns_nameservers" {
  description = "Route53 nameservers — вказати в реєстраторі домену"
  value       = aws_route53_zone.main.name_servers
}

output "acm_certificate_arn" {
  description = "ACM wildcard certificate ARN for HTTPS listener"
  value       = aws_acm_certificate.wildcard.arn
}
