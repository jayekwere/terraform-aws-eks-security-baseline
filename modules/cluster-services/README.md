# Strict-mode DNS bootstrap

Creates a policy selecting kube-system CoreDNS pods, then installs the exact CoreDNS add-on build. Ingress is TCP/UDP 53 from cluster namespaces. Egress is TCP 443 to the supplied VPC CIDR and the Kubernetes service IP (`cidrhost(service_cidr, 1)`). The VPC allowance accommodates rotating private API ENIs; it also reaches other VPC HTTPS endpoints. It is not an exact API-IP allowlist.

Use [the policies example](../../examples/policies) **after** the cluster exists, from a client allowed to reach its private endpoint. Requires AWS and Kubernetes providers and a compatible CoreDNS build. Do not use this child module on a cluster with an existing CoreDNS owner without planning an import/migration. It does not relabel kube-system or manage other system workloads. Strict mode requires explicit policies for additional ordinary system pods too.
