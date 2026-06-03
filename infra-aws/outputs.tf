output "vpc_id" {
  description = "ID of the created VPC."
  value       = module.vpc.vpc_id
}

output "vpc_public_subnets" {
  description = "IDs of the public subnets."
  value       = module.vpc.public_subnets
}

output "vpc_private_subnets" {
  description = "IDs of the private subnets."
  value       = module.vpc.private_subnets
}

output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint of the EKS cluster API server."
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded CA certificate for the EKS cluster."
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "my_app_security_group_id" {
  description = "ID of the custom application security group."
  value       = module.my_app_sg.security_group_id
}
