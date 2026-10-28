# Technical decisions and source review

Reviewed 2026-10-28. AWS documentation and regional service availability change; rerun the preflight queries before any deployment. Design inferences below are not claims of live AWS verification.

## Compose a reviewed EKS module

Use upstream EKS **21.29.0**, commit `91f11ea01656c26b8e6b8eb1b74f19863f60056c`, and its real typed interfaces. Its [provider contract](https://github.com/terraform-aws-modules/terraform-aws-eks/blob/91f11ea01656c26b8e6b8eb1b74f19863f60056c/versions.tf) requires AWS `>= 6.59`. This module constrains AWS `< 7`, Kubernetes `< 3`, and Terraform `< 2`; lockfiles record the actual tested selections. Module source pinning is independent of provider lockfiles. Transitive module retrieval remains an upstream dependency.

The wrapper accepts no general `eks_managed_node_groups`, extra IAM policies, public endpoint switch, arbitrary access policies or CNI JSON overrides. A separate node role uses the standard worker policy and pull-only ECR policy instead of the upstream default ECR read policy. This narrows choices but cannot eliminate the AWS-managed worker/CNI policies' required resource-wide APIs.

## Private API and explicit access

[AWS private endpoint requirements](https://docs.aws.amazon.com/eks/latest/userguide/cluster-endpoint.html) establish the DNS/connectivity prerequisites. Network data checks reject common subnet mistakes; NAT gateways, proxies, transit routing and endpoint policies remain caller responsibilities.

[Access entries](https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html) replace `aws-auth` handling. The creator receives no implicit admin. An explicitly named recovery role gets cluster admin, while viewers get exact namespace scopes. EKS access-policy and Kubernetes RBAC grants are additive. Changing IAM role trust is outside this module.

## Strict CNI and two-phase DNS bootstrap

[AWS network-policy configuration](https://docs.aws.amazon.com/eks/latest/userguide/cni-network-policy-configure.html) describes standard mode's startup allow window and strict mode's default deny, including CoreDNS. The design inference is to withhold CoreDNS from phase 1, create its policy through the already reachable private API, then create the add-on with an explicit Terraform dependency. This ordering is tested structurally and in plans; AWS startup/readiness remains unverified.

[AWS CNI limitations](https://docs.aws.amazon.com/eks/latest/userguide/cni-network-policy.html) include Linux EC2 scope, interface/address-family constraints and special handling of host/controller-owned pods. Use Deployments or Jobs for future dataplane probes, not standalone pods. The local standalone Pod fixture tests **admission only**. No DNS encryption, L7 filtering or guaranteed node-traffic isolation is implied. CoreDNS ingress permits TCP/UDP 53 from cluster namespaces; its only egress is TCP 443 to the VPC CIDR and the Kubernetes service IP. That VPC allowance is broader than the API ENIs, deliberately avoiding brittle IP pinning during control-plane changes.

## Workload admission and identity

[Kubernetes restricted Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/) define the implemented admission boundary. Labels pin a policy version rather than `latest`. Additional root-filesystem and token settings in the sample are workload choices; local negative-boundary probes demonstrate that PSA does not enforce them.

[Pod Identity trust](https://docs.aws.amazon.com/eks/latest/userguide/pod-id-role.html) supports request-tag conditions. The module checks cluster ARN, namespace and service account together, rather than only a reusable name. [AWS Pod Identity considerations](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html) define supported nodes, supported SDK credentials, eventual consistency and agent link-local connectivity. A role association alone never grants network connectivity or Kubernetes RBAC.

## KMS where it adds a boundary

[AWS default envelope encryption guidance](https://docs.aws.amazon.com/eks/latest/userguide/enable-kms.html) states that EKS 1.28+ provides default encryption. The supported range needs no extra cluster CMK merely to claim encrypted secrets. Disabling upstream CMK creation does not disable AWS's default encryption.

A separate customer-managed **log** key is justified by independent audit readership and retention availability. Its CloudWatch service policy is constrained to the exact log-group encryption context. Optional named readers receive decrypt/describe through the regional Logs service; they also need separate Logs IAM permissions. [CloudWatch KMS documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/encrypt-log-data-kms.html) explains that disabling the key makes old logs unreadable. Key administration permits changing the key policy and is therefore trusted, regardless of omitted direct decryption grants. `Resource = "*"` inside a KMS key policy means that key, not all account keys.

## Version and test evidence

[EKS support lifecycle](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html) lists the reviewed minor range; actual add-on compatibility still comes from the region/minor-specific API. Input shape checks cannot prove a build exists. This project's attempted compatibility query returned `NoCredentials`; no build compatibility output is invented. Mock test build strings are explicitly synthetic.

[Terraform mocked-provider semantics](https://developer.hashicorp.com/terraform/language/tests/mocking) allow provider schemas and computed test data without contacting AWS. The tests set `override_during = plan` to inspect concrete mock references. They exercise module composition, not service APIs, IAM policy evaluation or network dataplanes. The source-mutation runner changes real implementation files in disposable copies and requires the relevant plan contract to fail.

## Distinct scope

Read-only review of `secure-aws-platform` at `2c57d6070e0bacabda309d3e65f241cc33f8e0ec` and `hardened-container-supply-chain` at `89200c5b590c638298b79a856fba5368e425f093` established the boundary. The former documents S3/KMS, audit/detection and remote-state resources. The latter implements container/image trust and associated admission verification. This project contributes reusable EKS provisioning, access entries, node/CNI identity separation, strict DNS bootstrap and namespace policy. Neither existing repository was modified.
