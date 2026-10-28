mock_provider "kubernetes" {}
variables {
  name        = "payments"
  psa_version = "v1.35"
}
run "restricted_namespace" {
  command = plan
  assert {
    condition     = kubernetes_namespace_v1.this.metadata[0].labels["pod-security.kubernetes.io/enforce"] == "restricted"
    error_message = "PSA enforcement must be restricted."
  }
  assert {
    condition     = kubernetes_namespace_v1.this.metadata[0].labels["pod-security.kubernetes.io/enforce-version"] == "v1.35"
    error_message = "PSA version must be pinned."
  }
  assert {
    condition     = !kubernetes_service_account_v1.workload.automount_service_account_token
    error_message = "Workload accounts must not automount Kubernetes API tokens."
  }
  assert {
    condition     = toset(kubernetes_network_policy_v1.default_deny.spec[0].policy_types) == toset(["Ingress", "Egress"]) && length(kubernetes_network_policy_v1.default_deny.spec[0].ingress) == 0 && length(kubernetes_network_policy_v1.default_deny.spec[0].egress) == 0
    error_message = "Default deny must isolate both directions."
  }
  assert {
    condition     = length(kubernetes_network_policy_v1.dns.spec[0].egress[0].to) == 1 && kubernetes_network_policy_v1.dns.spec[0].egress[0].to[0].namespace_selector[0].match_labels["kubernetes.io/metadata.name"] == "kube-system" && kubernetes_network_policy_v1.dns.spec[0].egress[0].to[0].pod_selector[0].match_labels["k8s-app"] == "kube-dns"
    error_message = "DNS namespace and pod selectors must share the SAME peer (AND semantics)."
  }
}
run "reject_system_namespace" {
  command = plan
  variables { name = "kube-system" }
  expect_failures = [var.name]
}
run "reject_unpinned_psa" {
  command = plan
  variables { psa_version = "latest" }
  expect_failures = [var.psa_version]
}
run "reject_default_account" {
  command = plan
  variables { service_account_name = "default" }
  expect_failures = [var.service_account_name]
}
