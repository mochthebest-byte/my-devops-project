output "node_security_group_id" {
  description = "Security Group ID for EKS nodes"
  value       = aws_security_group.nodes.id
}

output "node_security_group_arn" {
  description = "Security Group ARN"
  value       = aws_security_group.nodes.arn
}
