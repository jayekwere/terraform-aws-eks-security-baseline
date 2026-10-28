variable "region" {
  description = "Same region as phase one."
  type        = string
  default     = "us-west-2"
}
variable "cluster_name" {
  description = "Existing cluster from phase one."
  type        = string
}
variable "bootstrap_admin_role_arn" {
  description = "Phase one's bootstrap role; caller needs sts:AssumeRole to use it for Kubernetes."
  type        = string
}
variable "vpc_cidr" {
  description = "Existing cluster VPC IPv4 CIDR."
  type        = string
}
variable "coredns_version" {
  description = "Exact region/minor-compatible CoreDNS build."
  type        = string
}
variable "reader_bucket_arn" {
  description = "Optional existing S3 bucket; reader role adds no network egress by itself."
  type        = string
  default     = null
}
