variable "vpc_id" {
  description = "The ID of the VPC where the security group will be created."
  type        = string
}

variable "ingress_ports" {
  description = "List of TCP ports to allow inbound traffic from 0.0.0.0/0."
  type        = list(number)
  default     = [80, 443]
}

variable "module_tags" {
  description = "Map of tags to apply to the security group."
  type        = map(string)
  default     = {}
}
