variable "tenancy_ocid" {
  description = "OCI Tenancy OCID"
  type        = string
}

variable "user_ocid" {
  description = "OCI User OCID"
  type        = string
}

variable "fingerprint" {
  description = "OCI API key fingerprint"
  type        = string
  sensitive   = true
}

variable "private_key_path" {
  description = "Path to OCI API private key"
  type        = string
}

variable "region" {
  description = "OCI Region"
  type        = string
  default     = "eu-frankfurt-1"
}

variable "compartment_ocid" {
  description = "OCI Compartment OCID (defaults to root compartment)"
  type        = string
}

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "voting-app"
}

variable "oke_node_shape" {
  description = "OKE node shape (free tier: VM.Standard.A1.Flex = 4 OCPU ARM)"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "oke_node_ocpus" {
  description = "Number of OCPUs per node"
  type        = number
  default     = 4
}

variable "oke_node_memory_gb" {
  description = "Memory per node in GB"
  type        = number
  default     = 24
}

variable "oke_node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "oke_k8s_version" {
  description = "Kubernetes version for OKE"
  type        = string
  default     = "v1.31.1"
}
