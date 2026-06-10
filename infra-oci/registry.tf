# ─── Container Registry ──────────────────────────────
resource "oci_artifacts_container_repository" "vote" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}/vote"
  is_public      = false
  readme {
    content = "Voting app — Vote service"
    format  = "text/markdown"
  }
}

resource "oci_artifacts_container_repository" "result" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}/result"
  is_public      = false
  readme {
    content = "Voting app — Result service"
    format  = "text/markdown"
  }
}

resource "oci_artifacts_container_repository" "worker" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.project_name}/worker"
  is_public      = false
  readme {
    content = "Voting app — Worker service"
    format  = "text/markdown"
  }
}

# Output the repository URLs
output "container_repos" {
  description = "OCI Container Registry URLs"
  value = {
    vote   = "${var.region}.ocir.io/${var.tenancy_ocid}/${oci_artifacts_container_repository.vote.display_name}"
    result = "${var.region}.ocir.io/${var.tenancy_ocid}/${oci_artifacts_container_repository.result.display_name}"
    worker = "${var.region}.ocir.io/${var.tenancy_ocid}/${oci_artifacts_container_repository.worker.display_name}"
  }
}
