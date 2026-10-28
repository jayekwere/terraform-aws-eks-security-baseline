# Verification and limits

Evidence is dated and tied to source hashes or a hosted commit. Source changes after a record require a new run. The [workflow](../.github/workflows/verify.yml) retains mock-plan JSON (repeated provider schemas omitted), run summaries and source commit IDs for 14 days. Public evidence contains synthetic identifiers only.

## Hosted result

[Run 40735904173](https://github.com/jayekwere/terraform-aws-eks-security-baseline/actions/runs/40735904173) passed all four jobs for `8effaa924fc248fb5ec8649b7d0271584d8c522d`. Both Terraform 1.15.8 and 1.17.0 passed 23 native runs, 26 composed-resource contracts and 13 rejected mutations. Admission passed all 12 requests (9 rejected, 3 accepted); authored-Terraform Checkov passed 40 checks with zero failures, skips or parsing errors. All artifacts were downloaded; both Terraform artifact commit IDs and implementation hashes matched the source. The [permanent record](evidence/hosted-verification.json) preserves job links, totals and evidence hashes. The release assets also preserve verification for the final release commit.

## Local result

- Terraform 1.15.8: **23 native runs** (4 positive plans, 19 required input/prerequisite rejections), with **26 composed-resource contracts**.
- **13 source mutations rejected**, including public API exposure, missing audit logs, extra creator administrator, standard CNI startup mode, metadata hop two, broad ECR read permission, weaker PSA, token automount, one-way isolation, wrong DNS selector, wildcard S3 action, wrong identity trust and removed DNS dependency.
- Six Terraform roots validate: root module, three children and two examples. Formatting, TFLint 0.65.0 (Terraform recommended rules) and actionlint 1.7.12 are checked.
- Checkov 3.3.30 scans authored Terraform with external-module downloads disabled. No blanket failure suppression or check exceptions are configured. This does **not** scan the vendored upstream module; composed-plan contracts cover selected upstream security behavior instead. No claim of exhaustive vulnerability discovery is made. tfsec is not additionally run because overlapping scanners would not supply AWS runtime evidence.
- Actual Kubernetes API admission: **12 dry-run requests**, with 9 expected rejections and 3 accepted controls/boundary probes. Namespace resources were applied by Terraform and destroyed afterward. No image was run.

Machine-readable records are in [`docs/evidence`](evidence). Check their timestamps/source hashes and the exact hosted revision before relying on totals. The hosted workflow independently exercises Terraform 1.15.8 and 1.17.0, lint/scanner checks and admission on Linux; consult the hosted record for actual outcomes rather than assuming the configured matrix passed.

Sample output from the actual local regression runner:

```text
.: 12 native runs, 16 composed-resource contracts passed
modules/namespace: 4 native runs, 5 composed-resource contracts passed
modules/cluster-services: 2 native runs, 3 composed-resource contracts passed
modules/pod-identity: 5 native runs, 2 composed-resource contracts passed
...
PASS: 23 native runs; 13 rejected source mutations
```

These plans use mocked providers, including synthetic compatible-shaped EKS builds and empty upstream generated IAM policy-document test data. They validate configuration propagation and our explicit policies, not the upstream policy generator or AWS's IAM evaluator. Mock computed values are generated during plan; tests cannot prove remote API acceptance.

## Real Kubernetes admission

Use Terraform 1.15.8, kind 0.33.0, kubectl 1.37.0, a local container runtime and this pinned kind node image:

```sh
kind create cluster --name eks-baseline-admission \
  --image kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5 \
  --kubeconfig /tmp/eks-baseline-kubeconfig --wait 120s
python3 scripts/test_admission.py --kubeconfig /tmp/eks-baseline-kubeconfig
kind delete cluster --name eks-baseline-admission
```

The runner refuses any other context and refuses an already existing test namespace. It applies the **actual namespace module**, then asks the API server to create synthetic objects with `--dry-run=server`. It destroys the namespace in a `finally` block. The cluster itself is owned by the caller and must be deleted separately; CI does so on success or failure. The test uses a Kubernetes 1.37 server enforcing the pinned `restricted:v1.35` standard; this is not an EKS platform test.

| Request | Expected and observed result |
| --- | --- |
| Restricted non-root, seccomp, dropped-capabilities pod | Accepted |
| Privileged / host networking / UID zero / privilege escalation | Rejected by PSA (4 requests) |
| NET_ADMIN capability / Unconfined seccomp / hostPath | Rejected by PSA (3 requests) |
| NodePort / LoadBalancer Service | Rejected by resource quota (2 requests) |
| Writable root filesystem, otherwise restricted | Accepted: outside PSA's enforced requirements |
| Explicit API-token automount, otherwise restricted | Accepted: outside PSA's enforced requirements |

No DNS packets, VPC CNI eBPF behavior, Pod Identity sessions, EC2 metadata requests, node bootstrapping, image execution, signing or cloud service behavior were tested by these requests.

## Exact remaining external blockers

**AWS:** no credentials were available. The read-only `describe-addon-versions` compatibility query returned `NoCredentials`. The user has not authorized billable infrastructure. Therefore no AWS plan against real resources, deployment, private endpoint probe, CNI traffic test, managed-node readiness test, access-entry authorization probe, STS/S3 test or real log-delivery/decryption test was performed. Operators must supply authorized credentials, network/state prerequisites and compatible regional add-on builds, then separately authorize billable deployment before live verification.

**Terraform Registry:** GitHub publication and a semantic release are usable as Git module sources. Registry enrollment requires an authenticated HCP Terraform/Registry account and authorization of this repository; no Registry session or token is configured for this task. A Registry listing is not claimed. See the [official publishing requirements](https://developer.hashicorp.com/terraform/registry/modules/publish). The repository name and module structure follow the public module convention.

## Security of CI and release

All third-party Actions are full-SHA pinned. Tool archives and the Kubernetes test image are pinned to verified checksums/digests. PRs run with `contents: read`, no AWS credentials, no persisted checkout token, no `pull_request_target`, and no release-writing job. Dependency packages have pinned direct versions, but their full transitive resolution and hosted runner images are not hermetically reproduced. Dependency updates require review and checks.

A release is published after successful hosted checks with source-bound evidence and SHA-256 checksums. Checksums detect changes relative to the release record; they are not independent cryptographic publisher identity. No artifact signature, verified-build attestation, immutable-release setting or external security audit is claimed unless separately recorded.

## Initial hosted portability failure

The first hosted run at implementation commit `e746bd7ed7f02494541f0cd916148246e46656f0` passed lint/scanning but failed Terraform/admission before tests because the lockfiles lacked Linux installed-package hashes. The repair adds HashiCorp-verified `linux_amd64` hashes while preserving provider versions. The initial local mock/admission results remain valid for their recorded source; the latest hosted/local records identify the corrected revision. The failed initial run is retained at [40735246559](https://github.com/jayekwere/terraform-aws-eks-security-baseline/actions/runs/40735246559).
