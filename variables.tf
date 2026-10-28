variable "name" {
  description = "Cluster name; kept short for generated IAM role prefixes."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,23}$", var.name))
    error_message = "Use 3-24 lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "kubernetes_version" {
  description = "Explicit EKS minor version. Recheck regional availability and support before apply."
  type        = string
  validation {
    condition     = contains(["1.34", "1.35", "1.36", "1.37"], var.kubernetes_version)
    error_message = "This release supports the reviewed EKS 1.34-1.37 minors only."
  }
}

variable "vpc_id" {
  description = "Existing IPv4 VPC with DNS support and hostnames enabled."
  type        = string
}

variable "private_subnet_ids" {
  description = "At least two existing private subnets in distinct availability zones; caller owns routing."
  type        = list(string)
  validation {
    condition     = length(toset(var.private_subnet_ids)) >= 2
    error_message = "Supply at least two distinct private subnet IDs."
  }
}

variable "api_client_security_group_ids" {
  description = "Existing security groups allowed to reach the private API on TCP 443."
  type        = set(string)
  validation {
    condition     = length(var.api_client_security_group_ids) > 0
    error_message = "At least one private API client security group is required."
  }
}

variable "bootstrap_admin_role_arn" {
  description = "Explicit IAM role for bootstrap/recovery. Receives cluster admin; protect its trust separately."
  type        = string
  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/.+$", var.bootstrap_admin_role_arn)) && !strcontains(var.bootstrap_admin_role_arn, "*")
    error_message = "Supply one concrete commercial-AWS IAM role ARN, not a user, session, root or wildcard."
  }
}

variable "namespace_viewers" {
  description = "Read-only EKS access policies, scoped to explicit workload namespaces. No edit/admin passthrough."
  type = map(object({
    principal_arn = string
    namespaces    = set(string)
  }))
  default = {}
  validation {
    condition = alltrue([for v in values(var.namespace_viewers) :
      can(regex("^arn:aws:iam::[0-9]{12}:role/.+$", v.principal_arn)) && !strcontains(v.principal_arn, "*") &&
      length(v.namespaces) > 0 && alltrue([for n in v.namespaces :
        can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", n)) && length(n) <= 63 &&
        !startswith(n, "kube-") && n != "default"
      ])
    ])
    error_message = "Viewers need concrete IAM role ARNs and exact, non-system namespaces; wildcard scopes are forbidden."
  }
  validation {
    condition     = length(distinct([for v in values(var.namespace_viewers) : v.principal_arn])) == length(var.namespace_viewers) && alltrue([for v in values(var.namespace_viewers) : v.principal_arn != var.bootstrap_admin_role_arn])
    error_message = "Access principals must be unique and different from the bootstrap administrator."
  }
}

variable "log_key_admin_role_arns" {
  description = "Explicit IAM roles allowed to administer the dedicated audit-log KMS key."
  type        = set(string)
  validation {
    condition     = length(var.log_key_admin_role_arns) > 0 && alltrue([for a in var.log_key_admin_role_arns : can(regex("^arn:aws:iam::[0-9]{12}:role/.+$", a)) && !strcontains(a, "*")])
    error_message = "Supply at least one concrete IAM role ARN for KMS administration."
  }
}

variable "log_reader_role_arns" {
  description = "Optional named audit readers. Also require separately managed CloudWatch Logs read permissions."
  type        = set(string)
  default     = []
  validation {
    condition     = alltrue([for a in var.log_reader_role_arns : can(regex("^arn:aws:iam::[0-9]{12}:role/.+$", a)) && !strcontains(a, "*")])
    error_message = "Audit readers must be concrete IAM role ARNs."
  }
}

variable "addon_versions" {
  description = "Exact region/minor-compatible add-on builds. Discover with describe-addon-versions; no latest lookup in this module."
  type = object({
    vpc_cni            = string
    pod_identity_agent = string
    kube_proxy         = string
  })
  validation {
    condition     = alltrue([for v in values(var.addon_versions) : can(regex("^v[0-9]+[.][0-9]+[.][0-9]+-eksbuild[.][0-9]+$", v))])
    error_message = "Each add-on needs an exact vX.Y.Z-eksbuild.N version."
  }
  validation {
    condition     = try(tonumber(split(".", trimprefix(var.addon_versions.vpc_cni, "v"))[0]) == 1 && tonumber(split(".", var.addon_versions.vpc_cni)[1]) >= 21, false)
    error_message = "Use a reviewed VPC CNI 1.21.x or later 1.x build for network policies."
  }
}

variable "node_instance_types" {
  description = "x86_64 AL2023-compatible EC2 types; availability and CPU architecture are caller prerequisites."
  type        = list(string)
  default     = ["m6i.large"]
  validation {
    condition     = length(var.node_instance_types) > 0
    error_message = "At least one x86_64 EC2 instance type is required."
  }
}

variable "deletion_protection" {
  description = "EKS deletion protection; explicitly disable and apply before teardown."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Resource tags. Do not include secrets or personal data."
  type        = map(string)
  default     = {}
}
