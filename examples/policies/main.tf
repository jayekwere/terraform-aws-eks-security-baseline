terraform {
  required_version = ">= 1.15.0, < 2.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.59.0, < 7.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.38.0, < 3.0.0"
    }
  }
}
provider "aws" { region = var.region }
data "aws_eks_cluster" "this" { name = var.cluster_name }
provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--region", var.region, "--cluster-name", var.cluster_name, "--role-arn", var.bootstrap_admin_role_arn]
  }
}
module "services" {
  source          = "../../modules/cluster-services"
  cluster_name    = var.cluster_name
  vpc_cidr        = var.vpc_cidr
  service_cidr    = data.aws_eks_cluster.this.kubernetes_network_config[0].service_ipv4_cidr
  coredns_version = var.coredns_version
}
module "workload_namespace" {
  source      = "../../modules/namespace"
  name        = "payments"
  psa_version = "v${data.aws_eks_cluster.this.version}"
}
# Optional: existing non-sensitive S3 prefix. No data is created or uploaded.
module "reader" {
  count           = var.reader_bucket_arn == null ? 0 : 1
  source          = "../../modules/pod-identity"
  cluster_arn     = data.aws_eks_cluster.this.arn
  namespace       = module.workload_namespace.name
  service_account = module.workload_namespace.service_account_name
  bucket_arn      = var.reader_bucket_arn
  object_prefix   = "reports/daily"
}
output "namespace" {
  description = "Restricted namespace with deny-all plus DNS egress."
  value       = module.workload_namespace.name
}
