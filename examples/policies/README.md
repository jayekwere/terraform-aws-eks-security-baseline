# Phase 2: DNS and workload policy

Run only after phase 1, with private API connectivity. Copy `terraform.tfvars.example` to ignored `terraform.tfvars`; supply the cluster name, bootstrap role, VPC CIDR and exact CoreDNS build. The caller must be allowed to assume the bootstrap role. AWS operations use the AWS provider's credentials; Kubernetes requests use short-lived tokens assuming the explicit bootstrap role.

Creates the CoreDNS network policy before the add-on; creates a restricted `payments` namespace. Setting `reader_bucket_arn` also creates the optional prefix-only reader identity. It does **not** grant AWS network egress; follow the [runbook](../../docs/operations.md). Default phase-2 workloads have DNS egress only.

Keep this state separate from the cluster state. Destroy phase 2 first, while the private API is reachable, because namespace destruction removes its contents. This example does not deploy an application or duplicate image verification from a supply-chain project.
