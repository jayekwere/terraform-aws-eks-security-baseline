variable "region" {
  description = "Commercial AWS region."
  type        = string
  default     = "us-west-2"
}
variable "name" {
  description = "New cluster name."
  type        = string
  default     = "eks-baseline-dev"
}
variable "kubernetes_version" {
  description = "Review version availability/support before apply."
  type        = string
  default     = "1.35"
}
variable "vpc_id" {
  description = "Existing DNS-enabled VPC."
  type        = string
}
variable "private_subnet_ids" {
  description = "Existing private subnets across two AZs."
  type        = list(string)
}
variable "api_client_security_group_ids" {
  description = "Security groups of private API clients."
  type        = set(string)
}
variable "bootstrap_admin_role_arn" {
  description = "Explicit cluster recovery/bootstrap role."
  type        = string
}
variable "log_key_admin_role_arns" {
  description = "Explicit audit key administrators, including the applying role."
  type        = set(string)
}
variable "addon_versions" {
  description = "Exact compatible builds selected from EKS API metadata."
  type = object({
    vpc_cni            = string
    pod_identity_agent = string
    kube_proxy         = string
  })
}
variable "deletion_protection" {
  description = "Explicitly disable/apply before reviewed teardown."
  type        = bool
  default     = true
}
