output "name" {
  description = "Managed namespace name."
  value       = kubernetes_namespace_v1.this.metadata[0].name
}
output "service_account_name" {
  description = "Workload account with token automount disabled."
  value       = kubernetes_service_account_v1.workload.metadata[0].name
}
