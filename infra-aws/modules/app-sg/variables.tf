variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block (for internal traffic)"
  type        = string
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
}
