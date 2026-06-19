# ══════════════════════════════════════════════════════════
#  GitHub Actions OIDC — Workload Identity Federation
# ══════════════════════════════════════════════════════════
#
#  Замінює статичні API-ключі на OIDC-токени від GitHub.
#  Див. налаштування OCI IdP далі.
#
#  Потрібно вручну створити OIDC Identity Provider:
#    OCI Console → Identity → Federation → Add OIDC IdP
#    - URL: https://token.actions.githubusercontent.com
#    - Client ID: https://github.com/<org>
#    - Отриманий OCID підставити в matching_rule нижче
# ══════════════════════════════════════════════════════════

# ─── Object Storage bucket for Terraform state ─────────
resource "oci_objectstorage_bucket" "tfstate" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "${var.project_name}-tfstate"
  access_type    = "NoPublicAccess"
  versioning     = "Enabled"
  storage_tier   = "Standard"
  meta_data = {
    "created-by" = "terraform"
    "purpose"    = "terraform-remote-state"
  }
}

data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_ocid
}

# ─── Dynamic Group для GitHub Actions ──────────────────
# Після створення OIDC IdP через OCI Console, додай OCID
# сюди та розкоментуй.
#
# resource "oci_identity_dynamic_group" "github_actions" {
#   compartment_id = var.tenancy_ocid
#   name           = "GitHubActions"
#   description    = "GitHub Actions workflows (via OIDC)"
#   matching_rule  = <<EOT
#     ALL {
#       resource.id = 'ocid1.oidcidentityprovider.oc1..<IDP_OCID>',
#       tag.github_actions.repository = '${var.github_allowed_repos}'
#     }
#   EOT
# }
#
# ─── Policy для GitHub Actions ─────────────────────────
# resource "oci_identity_policy" "github_actions" {
#   compartment_id = var.tenancy_ocid
#   name           = "GitHubActionsPolicy"
#   description    = "Permissions for GitHub Actions CI/CD"
#   statements = [
#     "Allow dynamic-group GitHubActions to manage clusters in compartment id ${var.compartment_ocid}",
#     "Allow dynamic-group GitHubActions to manage repos in compartment id ${var.compartment_ocid}",
#     "Allow dynamic-group GitHubActions to read objectstorage-buckets in compartment id ${var.compartment_ocid}",
#   ]
# }
