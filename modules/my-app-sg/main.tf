resource "aws_security_group" "this" {
  name        = "my-app-sg"
  description = "Security group for my application — HTTP/S inbound, all outbound."
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.module_tags, {
    Name = "my-app-sg"
  })
}
