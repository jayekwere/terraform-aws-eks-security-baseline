# Security policy

Only the newest 0.x release is maintained. This is a development baseline with no production support SLA. The threat model and verification limits are part of the security contract.

Use the repository's **Security → Report a vulnerability** feature for a sensitive report. If unavailable, open an issue requesting a private reporting channel without exploit details, secrets or affected account identifiers. Do not post credentials, Terraform state, kubeconfigs or raw production plans.

Useful reports include the exact revision, affected module, input/preconditions, expected versus actual behavior, trust boundary crossed, and a minimal synthetic reproduction. Static scanner output alone is a candidate, not proof. Do not probe another user's AWS account or incur cloud charges to demonstrate a finding.

Expected limitations include cluster-administrator control, writable namespace policy objects for privileged operators, PSA's documented scope, AWS-managed IAM policies, network-policy implementation exceptions, and the absence of live EKS verification. A defect in an implemented guarantee is still reportable even when a related limitation is documented.
