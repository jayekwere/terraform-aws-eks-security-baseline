# Threat model

## Assets and trust boundaries

Protect access to the Kubernetes API, AWS workload credentials, control-plane audit data and workload-to-workload traffic. Boundaries are (1) internet/connected networks to the private API, (2) IAM authentication and EKS authorization, (3) application pods versus host/kernel and neighboring namespaces, (4) one Pod Identity binding versus another AWS principal, and (5) audit service/readers versus KMS administrators.

Assume a new, dedicated IPv4 EKS cluster; trusted AWS account administrators and cluster bootstrap administrators; authentic upstream providers/modules; caller-owned VPC, DNS, routing, EC2 endpoints and backend; Linux nodes with functional VPC CNI policy agent; no pre-existing compromised privileged DaemonSet; and reviewed changes to this module. The examples do not establish those external prerequisites automatically.

## Attacker and control matrix

| Attacker / scenario | Implemented control | Residual limit / verification |
| --- | --- | --- |
| Internet client targets Kubernetes API | Public endpoint disabled; private API ingress from explicit client SGs and required node/control-plane rules | Connected networks can still reach authorized paths; IAM and Kubernetes authorization remain required. Plan tested, not AWS probed. |
| Unintended provisioner becomes cluster admin | Creator bootstrap admin disabled; one explicit role access entry | That role is powerful by design. AWS principals able to change access entries or assume that role can regain control. Composed-plan and mutation tested. |
| Viewer reads/writes outside its workload namespace | Fixed View policy, exact namespace scope, no wildcard or edit/admin passthrough | EKS and Kubernetes RBAC permissions are additive. Extra externally managed grants can broaden effective access. No live EKS authorizer test. |
| Compromised ordinary pod attempts host privilege | Restricted PSA on managed namespaces, IMDSv2 hop one; no SSH key | Shared kernel, privileged system agents, node vulnerabilities and host-network exceptions remain. Local API rejected privileged/host/root/escalation/capability/seccomp/hostPath variants. No kernel escape test. |
| Compromised pod moves laterally or sends arbitrary egress | Strict CNI mode; bidirectional default deny plus selected CoreDNS only | AWS CNI prerequisites and exceptions apply; policies are additive; namespace writers can broaden them. DNS can carry data. Actual AWS dataplane untested. |
| Workload tries to obtain CNI/node permissions | CNI role separate from node; exact Pod Identity request tags; IMDS hop one | Host-level compromise defeats pod-level identity isolation. AWS-managed worker/CNI policies remain broad where service APIs require it. Terraform-tested only. |
| Wrong service account/cluster reuses S3 reader role | Exact cluster ARN (region/account), namespace and service account request tags; one GetObject prefix | Someone who can create pods as that account can use its identity. External bucket/role policies can broaden effective access. No live STS/S3 call. |
| Workload creates public Services or consumes unbounded namespace objects | Quota denies NodePort/LoadBalancer Services, caps pods and compute; LimitRange supplies container defaults | Does not prevent ingress controllers, host agents, arbitrary DNS names, Ingress objects or all resource exhaustion paths. Public Service quota exercised on local API. |
| Audit evidence is exposed or removed | Five logs, dedicated rotating key, exact log context, named readers and key admins, 90-day retention | Trusted administrators can change policies, delete logs or disable KMS. No immutable archive, alarms, CloudTrail configuration or delivery proof. |
| Untrusted PR attempts to exfiltrate cloud credentials or publish | No AWS credentials, read-only GitHub permission, SHA actions, disabled checkout persistence, no privileged PR trigger | Runner, downloaded dependencies and upstream registries remain supply-chain dependencies. Hosted platform administrators remain trusted. |

## Explicit non-goals

No protection against a malicious AWS root/account admin, KMS admin or cluster admin. No hostile multi-tenant isolation guarantee; no node-level microsegmentation; no image signature/digest admission; no read-only-root or mandatory-token-denial admission; no secret store/rotation; no ingress, TLS service mesh, WAF, runtime threat detector, immutable audit archive or backup/restore implementation. No alternate CNI, Fargate, Windows, Auto Mode, hybrid, GovCloud/China or IPv6 support.

The S3 reader is a deliberately narrow teaching contract. It is not a general-purpose IAM policy generator. The project does not claim least privilege for every AWS-managed policy or for the separate Terraform deployment identity.

## Acceptance and future live verification

Current acceptance means schema-valid source, rejected unsafe inputs, expected composed plans, detected control mutations, clean configured lint/scanner checks and matching real local admission decisions. It does not imply operational EKS readiness. Before production, prove CNI startup/DNS and blocked traffic with controller-owned workloads, access-entry authorization, Pod Identity credentials, real log delivery/decryption, upgrade/recovery and teardown in an authorized isolated AWS environment.
