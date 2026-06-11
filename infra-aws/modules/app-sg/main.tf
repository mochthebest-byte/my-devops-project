# ══════════════════════════════════════════════════════════
#  Власний модуль: Security Group для EKS nodes
#  LB → Nodes (NodePort), Nodes → інтернет
# ══════════════════════════════════════════════════════════

# ─── Node Security Group ──────────────────────────────
resource "aws_security_group" "nodes" {
  name_prefix = "${var.project_name}-nodes-"
  description = "Security group for EKS worker nodes"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.project_name}-nodes" })
}

# ─── Ingress: LB → Nodes (NodePort range) ────────────
resource "aws_vpc_security_group_ingress_rule" "lb_to_nodes_np" {
  security_group_id = aws_security_group.nodes.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 30000
  to_port           = 32767
  ip_protocol       = "tcp"
  description       = "NodePort traffic"
}

# ─── Ingress: внутрішній трафік VPC ──────────────────
resource "aws_vpc_security_group_ingress_rule" "vpc_internal" {
  security_group_id = aws_security_group.nodes.id
  cidr_ipv4         = var.vpc_cidr
  from_port         = 0
  to_port           = 65535
  ip_protocol       = "tcp"
  description       = "Internal VPC traffic"
}

# ─── Egress: весь трафік назовні ─────────────────────
resource "aws_vpc_security_group_egress_rule" "nodes_all" {
  security_group_id = aws_security_group.nodes.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "All outbound traffic"
}

output "node_security_group_id" {
  description = "Security Group ID for EKS nodes"
  value       = aws_security_group.nodes.id
}
