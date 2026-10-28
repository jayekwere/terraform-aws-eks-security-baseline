terraform {
  required_version = ">= 1.15.0, < 2.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.59.0, < 7.0.0"
    }
  }
}
provider "aws" { region = var.region }
module "baseline" {
  source = "../.."

  name                          = var.name
  kubernetes_version            = var.kubernetes_version
  vpc_id                        = var.vpc_id
  private_subnet_ids            = var.private_subnet_ids
  api_client_security_group_ids = var.api_client_security_group_ids
  bootstrap_admin_role_arn      = var.bootstrap_admin_role_arn
  log_key_admin_role_arns       = var.log_key_admin_role_arns
  addon_versions                = var.addon_versions
  deletion_protection           = var.deletion_protection
  tags                          = { Project = "eks-security-baseline", Environment = "development" }
}
output "cluster_name" {
  description = "Cluster to supply to phase two."
  value       = module.baseline.cluster_name
}
output "log_key_arn" {
  description = "Audit-log key; retain it during teardown."
  value       = module.baseline.log_key_arn
}
