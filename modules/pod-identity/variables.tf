variable "cluster_arn" {
  description = "Exact cluster ARN, including account and region, for Pod Identity request-tag trust."
  type        = string
  validation {
    condition     = can(regex("^arn:aws:eks:[a-z0-9-]+:[0-9]{12}:cluster/[a-zA-Z0-9][a-zA-Z0-9_-]*$", var.cluster_arn))
    error_message = "Supply a concrete commercial-AWS EKS cluster ARN."
  }
}
variable "namespace" {
  description = "Exact workload namespace."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.namespace)) && length(var.namespace) <= 63 && var.namespace != "default" && !startswith(var.namespace, "kube-")
    error_message = "Use an exact non-system workload namespace."
  }
}
variable "service_account" {
  description = "Exact dedicated workload service account name."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.service_account)) && length(var.service_account) <= 63 && var.service_account != "default"
    error_message = "Use a dedicated DNS-label service account, not default."
  }
}
variable "bucket_arn" {
  description = "Existing S3 bucket ARN for a bounded GetObject-only demonstration; bucket policy still applies."
  type        = string
  validation {
    condition     = can(regex("^arn:aws:s3:::[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_arn))
    error_message = "Supply one concrete S3 bucket ARN, without object suffixes or wildcards."
  }
}
variable "object_prefix" {
  description = "Nonempty object prefix without leading/trailing slashes, wildcards or dot segments."
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+(/[a-zA-Z0-9_-]+)*$", var.object_prefix))
    error_message = "Supply a nonempty bounded prefix such as reports/daily; wildcards and dot segments are forbidden."
  }
}
