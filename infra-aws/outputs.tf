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
