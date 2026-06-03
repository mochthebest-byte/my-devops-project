variable "name" {
  description = "Name tag for the security group."
  type        = string
  default     = "my-app-sg"
}

variable "description" {
  description = "Description of the security group."
  type        = string
  default     = "Security group for the my-app workload."
}

variable "vpc_id" {
  description = "ID of the VPC in which to create the security group."
  type        = string
}

variable "ingress_rules" {
  description = <<-EOT
    List of ingress rule objects. Each object supports:
      - description   (string, optional)
      - from_port     (number, required)
      - to_port       (number, required)
      - protocol      (string, required) — e.g. "tcp", "udp", "-1"
      - cidr_blocks   (list(string), optional) — defaults to []
      - ipv6_cidr_blocks (list(string), optional) — defaults to []
  EOT
  type = list(object({
    description   = optional(string, "")
    from_port     = number
    to_port       = number
    protocol      = string
    cidr_blocks   = optional(list(string), [])
    ipv6_cidr_blocks = optional(list(string), [])
  }))
  default = [
    {
      description = "HTTP from anywhere"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "HTTPS from anywhere"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
  ]
}

variable "module_tags" {
  description = "Common tags to apply to the security group."
  type        = map(string)
  default     = {}
}
