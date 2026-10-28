# Phase 1: private cluster

Requires existing networking, named administrator/key roles and region/minor-compatible add-on builds. Copy `terraform.tfvars.example` to ignored `terraform.tfvars` and replace **all** identifiers/build placeholders. Credentials come from the standard AWS chain. Use an encrypted, locked backend for any real deployment; these examples intentionally leave backend ownership to the caller.

Initialize, validate and review a plan. Applying creates billable EKS, EC2, KMS and logging resources. **No AWS deployment is authorized or performed by this repository's CI.** Phase 1 does not install CoreDNS. Continue with [phase 2](../policies) and the [runbook](../../docs/operations.md).
