# Preflight and two-phase operations

These are operator instructions, **not evidence that deployment occurred**. Applying is billable. Obtain separate deployment authorization and review account costs before creating EKS/EC2/KMS/logging resources. CI never applies AWS resources.

## 1. Establish prerequisites

Use a dedicated development account/region and temporary credentials. Protect both Terraform states with encrypted storage, access controls, versioning and locking; examples intentionally do not create a backend. Plan/state files contain sensitive infrastructure metadata and must stay out of Git. Match the checked-in provider lockfiles, and inspect dependency upgrades deliberately.

Supply an existing IPv4 VPC with Amazon-provided DNS, DNS hostnames/support enabled, and private subnets in at least two AZs with enough free IP addresses. No direct internet-gateway routes or automatic public-IP assignment are accepted. The module does not prove that NAT/proxy/transit routes are safe or usable. For isolated VPCs, provision the appropriate regional interface/gateway endpoints and private DNS: EKS management API for operators, EKS Auth for Pod Identity, ECR API/DKR and S3 for image layers, EC2 for CNI, and other APIs used by your agents/workloads. Endpoint policies and SGs must permit only the intended clients. Outbound internet via a controlled NAT path is an alternative; private API access does not mean zero internet egress.

The applying AWS role needs EKS/IAM/EC2/Logs/KMS management permissions for this deployment and `iam:PassRole` on the relevant roles. This project does not ship a misleading universal deployment policy. Protect and review the bootstrap role's trust separately; the Kubernetes phase's caller must be allowed to assume it. Include the applying IAM role in `log_key_admin_role_arns` so KMS lockout safety checks can succeed. Logs read permissions belong on explicit operational reader roles; list them in `log_reader_role_arns` for key use too.

The private client runner must be in the VPC or a connected network, resolve the EKS endpoint to private addresses and be represented by an allowed API-client SG where SG referencing is supported. Its egress and routes must reach the private API. A stock internet-hosted GitHub runner cannot directly apply phase 2. Do not enable a public endpoint to work around missing connectivity.

## 2. Discover real versions, then pin them

With authorized **read-only AWS API access**, review support and add-on versions:

```sh
aws eks describe-cluster-versions --region us-west-2
aws eks describe-addon-versions --region us-west-2 --kubernetes-version 1.35 \
  --query 'addons[?addonName==`vpc-cni` || addonName==`kube-proxy` || addonName==`eks-pod-identity-agent` || addonName==`coredns`].{name:addonName,builds:addonVersions[].{version:addonVersion,compatibilities:compatibilities}}'
```

Select compatible, supported builds and record them in ignored `terraform.tfvars`. VPC CNI must be 1.21.x or a newer 1.x build for this release. Inspect each selected add-on schema rather than assuming that version formatting proves compatibility:

```sh
aws eks describe-addon-configuration --region us-west-2 \
  --addon-name vpc-cni --addon-version YOUR_EXACT_BUILD
```

Confirm support for `enableNetworkPolicy`, `env.NETWORK_POLICY_ENFORCING_MODE` and Pod Identity for `aws-node`. Confirm agent compatibility and node-policy support for `eks-auth:AssumeRoleForPodIdentity`. AL2023 must have kernel 5.10+; instance types must support x86_64 and exist in the chosen AZs. Verify all of this against AWS metadata before plan approval. This project's attempt at the regional query returned **NoCredentials**, so its tests use synthetic build strings and provide no regional compatibility claim.

## 3. Phase 1: review AWS resources

Copy the cluster example's `.example` values, replace all placeholders, initialize the real protected backend, and confirm your AWS identity/account. Static checks use `-backend=false` solely for validation; deployment must deliberately configure its backend.

```sh
terraform -chdir=examples/cluster init
terraform -chdir=examples/cluster plan -out=reviewed.tfplan
```

Review the private endpoint, source SGs, two-node capacity, access entries, dedicated CNI/node roles, log key/retention and exact add-on builds. After explicit cost/deployment approval, the operator may apply the saved plan. This document does not grant that authorization.

Expect CoreDNS to be absent after this phase. CNI, Pod Identity agent and kube-proxy are managed here. Do not add CoreDNS to this phase's module inputs: strict mode would block it before its policy exists, and the add-on can wait for health while the next root has not run.

## 4. Phase 2: policies before DNS

From the private client, configure the policies example with the cluster, VPC CIDR, explicit bootstrap role and exact CoreDNS version. Initialize a separate backend and review its plan. Kubernetes authentication uses `aws eks get-token` with the named role on each provider invocation, rather than storing a static token.

The actual dependency is `CoreDNS NetworkPolicy -> CoreDNS add-on`. The policy permits DNS ingress from cluster namespaces and API HTTPS egress to the VPC plus service IP. The VPC CIDR is wider than just the API ENIs; tighten using a well-maintained alternative only after accounting for API address rotation. Other added non-host-network system workloads also need explicit strict-mode policies.

After an authorized apply, verify readiness and configuration from the private network:

```sh
aws eks describe-cluster --region us-west-2 --name eks-baseline-dev
kubectl -n kube-system rollout status deployment/coredns
kubectl -n kube-system get daemonset aws-node eks-pod-identity-agent kube-proxy
kubectl -n kube-system get networkpolicy baseline-coredns -o yaml
kubectl get namespace payments --show-labels
kubectl -n payments get networkpolicy,resourcequota,limitrange,serviceaccount
```

Use the correct explicit kubeconfig/context. These commands are supplied for operators; they have not been run against EKS by this project.

## 5. Add workloads and identity deliberately

Review [`fixtures/restricted-pod.json`](../fixtures/restricted-pod.json) for security-context defaults. It is a **standalone admission fixture**, not a network probe or a production workload. Use controller-owned Deployments/Jobs for CNI tests. Avoid deploying the pause fixture as an application; it has no business behavior or readiness contract. PSA does not require its read-only filesystem, resource choices, image digest or token setting.

Default namespace policies allow DNS only. To use the optional S3 reader, create a workload using its exact dedicated service account, with a supported SDK default credential chain. Review narrow egress policies for the node-local agent `169.254.170.23/32` TCP 80 and your chosen private S3 endpoint addresses TCP 443. Gateway endpoints use S3 prefix-list routing; standard Kubernetes NetworkPolicy cannot directly reference a managed AWS prefix list. Resolve/maintain appropriate destination ranges or use a deliberately designed proxy/alternate egress mechanism. Do not open `0.0.0.0/0` as a shortcut.

Confirm proxy exclusions for the agent, EKS Auth reachability from the node, bucket policy, and whether KMS decryption is needed. The reader module intentionally does not grant KMS. Do not grant the namespace an edit role unless you accept that it can choose service accounts and alter namespaced NetworkPolicies. EKS View entries are read-only; there is no application deployer role in this release.

Before adoption, record real allowed/denied traffic, metadata isolation, wrong-namespace/role access-entry requests, wrong-service-account AWS requests, GetObject allowed/denied prefixes, log arrival/decryption and service-health evidence. A working DNS query alone is not proof that deny policies are enforced.

## 6. Upgrade and recovery

Pin a reviewed release commit. Upgrade one EKS minor at a time according to the current supported upgrade path, check readiness/add-on compatibility and node AMI support, then test policies. Keep the namespace PSA version pinned until the next policy version is evaluated; the example follows the cluster version and therefore its plan requires review during upgrades. Avoid simultaneous provider/module/cluster/CNI upgrades.

A named bootstrap role is intentional recovery authority, not a tightly scoped application role. Protect it with federation/MFA, controlled trust and monitored assumptions. Validate the access entry before removing alternate recovery paths. Terraform credentials and IAM authority to manage access entries remain privileged independently of Kubernetes access.

Treat audit key disablement, CNI/agent failure, lost private DNS and backend access loss as availability incidents. No automated remediation or monitoring receiver is configured. Maintain external recovery access and tested backups before using this outside a development account.

## 7. Teardown safely

Delete application resources and destroy **phase 2 first**, while the private API still exists and is reachable. Namespace destruction deletes its contents. Preserve required audit data before deleting the cluster root.

Set the cluster example's `deletion_protection = false`, review/apply that change, then review destruction. The log key has Terraform `prevent_destroy = true`, so an unreviewed full destroy is expected to fail. Decide whether to migrate the retained log/key resources into separately managed state, or deliberately remove that guard in a reviewed source change after retention/recovery requirements are satisfied. The key's configured deletion window is 30 days; disabling/deleting it can make historical logs unreadable. The log group's 90-day retention does not prevent explicit deletion.

Do not remove state records as a substitute for deleting or transferring ownership of resources. Check for lingering EC2, add-ons, network attachments, log storage and keys afterward. No teardown against AWS was attempted here.
