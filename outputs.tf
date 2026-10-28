output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}
output "cluster_arn" {
  description = "EKS ARN for exact Pod Identity trust scope."
  value       = module.eks.cluster_arn
}
output "cluster_endpoint" {
  description = "Private Kubernetes API endpoint."
  value       = module.eks.cluster_endpoint
}
output "cluster_certificate_authority_data" {
  description = "Base64 CA for the Kubernetes provider (not a credential)."
  value       = module.eks.cluster_certificate_authority_data
}
output "cluster_service_cidr" {
  description = "Kubernetes IPv4 service CIDR for CoreDNS API egress."
  value       = module.eks.cluster_service_cidr
}
output "log_key_arn" {
  description = "Dedicated CloudWatch Logs key. EKS API data uses AWS default envelope encryption."
  value       = aws_kms_key.logs.arn
}
