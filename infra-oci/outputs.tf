output "cluster_id" {
  description = "OKE Cluster OCID"
  value       = oci_oke_cluster.main.id
}

output "cluster_kubeconfig" {
  description = "Command to get kubeconfig for the cluster"
  value       = "oci ce cluster create-kubeconfig --cluster-id ${oci_oke_cluster.main.id} --file ~/.kube/config --region ${var.region} --token-version 2.0.0"
}

output "vcn_id" {
  description = "VCN OCID"
  value       = oci_core_vcn.main.id
}

output "node_pool_id" {
  description = "Node pool OCID"
  value       = oci_oke_node_pool.main.id
}

output "region" {
  description = "OCI Region"
  value       = var.region
}
