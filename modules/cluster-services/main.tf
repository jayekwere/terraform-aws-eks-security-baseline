# Strict CNI mode requires DNS policy BEFORE CoreDNS is created.
resource "kubernetes_network_policy_v1" "coredns" {
  metadata {
    name      = "baseline-coredns"
    namespace = "kube-system"
  }
  spec {
    pod_selector {
      match_labels = { "k8s-app" = "kube-dns" }
    }
    policy_types = ["Ingress", "Egress"]
    ingress {
      from {
        namespace_selector {}
      }
      ports {
        protocol = "UDP"
        port     = "53"
      }
      ports {
        protocol = "TCP"
        port     = "53"
      }
    }
    egress {
      to {
        ip_block { cidr = var.vpc_cidr }
      }
      to {
        ip_block { cidr = "${cidrhost(var.service_cidr, 1)}/32" }
      }
      ports {
        protocol = "TCP"
        port     = "443"
      }
    }
  }
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = var.cluster_name
  addon_name                  = "coredns"
  addon_version               = var.coredns_version
  resolve_conflicts_on_create = "NONE"
  resolve_conflicts_on_update = "NONE"
  preserve                    = false
  depends_on                  = [kubernetes_network_policy_v1.coredns]
}
