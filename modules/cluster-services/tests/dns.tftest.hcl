mock_provider "kubernetes" {}
mock_provider "aws" {}
variables {
  cluster_name    = "baseline-test"
  vpc_cidr        = "10.20.0.0/16"
  service_cidr    = "172.20.0.0/16"
  coredns_version = "v1.12.4-eksbuild.1"
}
run "dns_bootstrap" {
  command = plan
  assert {
    condition     = kubernetes_network_policy_v1.coredns.spec[0].pod_selector[0].match_labels["k8s-app"] == "kube-dns" && toset(kubernetes_network_policy_v1.coredns.spec[0].policy_types) == toset(["Ingress", "Egress"])
    error_message = "DNS policy must select CoreDNS and isolate both directions."
  }
  assert {
    condition     = toset([for p in kubernetes_network_policy_v1.coredns.spec[0].ingress[0].ports : "${p.protocol}/${p.port}"]) == toset(["TCP/53", "UDP/53"])
    error_message = "DNS ingress must be TCP/UDP 53 only."
  }
  assert {
    condition     = toset([for p in kubernetes_network_policy_v1.coredns.spec[0].egress[0].to : p.ip_block[0].cidr]) == toset(["10.20.0.0/16", "172.20.0.1/32"])
    error_message = "DNS must reach the private API and its service IP."
  }
}
run "reject_unbounded_api_egress" {
  command = plan
  variables { vpc_cidr = "0.0.0.0/0" }
  expect_failures = [var.vpc_cidr]
}
