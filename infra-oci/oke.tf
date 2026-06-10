# ─── OKE Cluster ─────────────────────────────────────
resource "oci_oke_cluster" "main" {
  compartment_id     = var.compartment_ocid
  name               = "${var.project_name}-oke"
  vcn_id             = oci_core_vcn.main.id
  kubernetes_version = var.oke_k8s_version
  endpoint_config {
    is_public_ip_enabled = true
    subnet_id           = oci_core_subnet.lb.id
  }
  options {
    service_lb_subnet_ids = [oci_core_subnet.lb.id]
    add_ons {
      is_kubernetes_dashboard_enabled = false
      is_tiller_enabled               = false
    }
  }
}

# ─── Node Pool ────────────────────────────────────────
resource "oci_oke_node_pool" "main" {
  compartment_id     = var.compartment_ocid
  cluster_id         = oci_oke_cluster.main.id
  name               = "${var.project_name}-nodepool"
  kubernetes_version = var.oke_k8s_version
  node_source_details {
    source_type = "IMAGE"
    image_id    = data.oci_core_images.oke.images[0].id
  }
  node_shape    = var.oke_node_shape
  node_shape_config {
    ocpus         = var.oke_node_ocpus
    memory_in_gbs = var.oke_node_memory_gb
  }
  node_config_details {
    size = var.oke_node_count
    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
      subnet_id           = oci_core_subnet.oke.id
    }
    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[1].name
      subnet_id           = oci_core_subnet.oke.id
    }
    # OKE labels + taints for node affinity
    node_pool_pod_network_option_details {
      cni_type = "FLANNEL_OVERLAY"
    }
  }
  initial_node_labels {
    key   = "app"
    value = var.project_name
  }
  ssh_public_key = var.ssh_public_key != "" ? var.ssh_public_key : null
}

# ─── Data Sources ─────────────────────────────────────
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

data "oci_core_images" "oke" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = var.oke_node_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

variable "ssh_public_key" {
  description = "SSH public key for OKE nodes (optional)"
  type        = string
  default     = ""
}
