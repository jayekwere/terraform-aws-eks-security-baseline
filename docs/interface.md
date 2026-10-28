# Module interfaces

The root configures providers through its caller. Credentials are never variables. Existing networking, IAM role trust and backend configuration belong to the caller.

## Root inputs

| Input | Required / default | Contract |
| --- | --- | --- |
| `name` | Required | 3–24 lowercase characters; cluster and IAM prefix |
| `kubernetes_version` | Required | Explicit reviewed 1.34–1.37 minor; recheck support |
| `vpc_id` | Required | Existing DNS-enabled commercial-AWS IPv4 VPC |
| `private_subnet_ids` | Required | Two or more distinct private subnet IDs; same VPC, two AZs, no public-IP assignment/direct IGW routes |
| `api_client_security_group_ids` | Required | Nonempty set of existing private API-client SGs; TCP 443 only |
| `bootstrap_admin_role_arn` | Required | One concrete IAM role with intentional cluster-admin authority |
| `log_key_admin_role_arns` | Required | Nonempty concrete IAM roles; include the applying role so key-policy safety checks succeed |
| `log_reader_role_arns` | `[]` | Optional exact roles; decrypt via Logs only; caller separately grants Logs read APIs |
| `namespace_viewers` | `{}` | Map of `{principal_arn, namespaces}`; unique roles; exact non-system namespaces; View only |
| `addon_versions` | Required | Exact `vpc_cni`, `pod_identity_agent`, `kube_proxy` EKS builds; CNI >= 1.21 in 1.x |
| `node_instance_types` | `["m6i.large"]` | Compatible x86_64 types available in your AZs; architecture is an external prerequisite |
| `deletion_protection` | `true` | Disable/apply before reviewed EKS teardown |
| `tags` | `{}` | Non-sensitive resource tags |

Outputs: `cluster_name`, `cluster_arn`, `cluster_endpoint`, `cluster_certificate_authority_data` (base64 public CA), `cluster_service_cidr`, `log_key_arn`. No token, private key or state credentials are returned.

Root fixed settings include two desired/on-demand managed nodes (minimum two, maximum three), AL2023 x86_64, 30 GiB gp3 encrypted root, API-only authentication, no IRSA issuer, strict VPC CNI and no phase-1 CoreDNS. Change source under review if these opinions do not fit; do not bypass them through hidden input maps.

## Child modules

- `cluster-services`: required `cluster_name`, `vpc_cidr` (/16 or narrower), `service_cidr`, `coredns_version`. Requires reachable Kubernetes API and AWS provider. It owns one kube-system CoreDNS policy and the CoreDNS add-on; no existing system namespace labels are changed.
- `namespace`: required `name`, `psa_version`; `service_account_name` defaults to `workload`. Outputs `name`, `service_account_name`. Owns a **new** namespace, dedicated account, two network policies, quota and LimitRange. PSA version must be supported by the API server; standalone child input validation cannot discover that server's version. The policies example derives it from EKS.
- `pod-identity`: required `cluster_arn`, `namespace`, `service_account`, `bucket_arn`, `object_prefix`; output `role_arn`. Owns a role, inline GetObject policy and association. Prefix accepts slash-delimited letters/digits/underscore/hyphen segments, deliberately excluding wildcards, dots and ambiguous slash endings. It creates no S3 data, bucket, service account, network policy or KMS grant.

Namespace budget: 20 pods, 4 CPU/8 GiB requests, 8 CPU/16 GiB limits, zero LoadBalancer/NodePort Services. Container default requests are 100m CPU/128 MiB and limits 500m CPU/256 MiB. Budgets are fixed in this development release. Read-only filesystem and explicit API-token denial require an additional admission mechanism if your threat model needs enforced invariants.
