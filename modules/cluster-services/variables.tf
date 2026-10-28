variable "cluster_name" {
  description = "Existing private EKS cluster name."
  type        = string
}
variable "vpc_cidr" {
  description = "IPv4 VPC CIDR containing the private EKS API ENIs, used for TCP 443 egress only."
  type        = string
  validation {
    condition     = can(cidrnetmask(var.vpc_cidr)) && try(tonumber(split("/", var.vpc_cidr)[1]) >= 16, false)
    error_message = "Supply a valid IPv4 VPC CIDR of /16 or narrower, not an internet-wide range."
  }
}
variable "service_cidr" {
  description = "IPv4 Kubernetes service CIDR; only its first host (kubernetes service) is allowed."
  type        = string
  validation {
    condition     = can(cidrnetmask(var.service_cidr))
    error_message = "Supply the cluster's IPv4 service CIDR."
  }
}
variable "coredns_version" {
  description = "Exact EKS CoreDNS add-on version verified for this cluster minor/region."
  type        = string
  validation {
    condition     = can(regex("^v[0-9]+[.][0-9]+[.][0-9]+-eksbuild[.][0-9]+$", var.coredns_version))
    error_message = "Use an exact CoreDNS vX.Y.Z-eksbuild.N build."
  }
}
