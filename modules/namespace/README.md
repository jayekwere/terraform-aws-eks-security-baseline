# Restricted workload namespace

Creates a new non-system namespace with version-pinned restricted PSA; a named service account without API-token automount; ingress/egress deny-all; combined namespace-and-pod CoreDNS selectors for TCP/UDP 53; and fixed quotas/LimitRange. Requires a functional network-policy CNI. Select PSA version no higher than the API server.

```hcl
module "payments" {
  source      = "../../modules/namespace" # or a pinned Git source //modules/namespace
  name        = "payments"
  psa_version = "v1.35"
}
```

Do not import existing namespaces casually: destroying this module deletes its namespace and its contents. Namespace writers can add permissive policies or select another service account; PSA does not deny explicit API-token requests or require read-only filesystems. See [interfaces](../../docs/interface.md), [threat model](../../docs/threat-model.md) and [admission evidence](../../docs/verification.md).
