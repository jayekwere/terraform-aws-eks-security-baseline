variable "name" {
  description = "New workload namespace; system and default namespaces are deliberately excluded."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.name)) && length(var.name) <= 63 && !startswith(var.name, "kube-") && var.name != "default"
    error_message = "Use an exact non-system namespace name of at most 63 characters."
  }
}
variable "psa_version" {
  description = "Pinned Pod Security Standards version, no higher than the API server minor."
  type        = string
  validation {
    condition     = contains(["v1.34", "v1.35", "v1.36", "v1.37"], var.psa_version)
    error_message = "Pin a reviewed v1.34-v1.37 PSA version; latest and older versions are forbidden."
  }
}
variable "service_account_name" {
  description = "Dedicated workload account; no Kubernetes RBAC grants or default API token."
  type        = string
  default     = "workload"
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.service_account_name)) && length(var.service_account_name) <= 63 && var.service_account_name != "default"
    error_message = "Use a named DNS-label service account, not default."
  }
}
