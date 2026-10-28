resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.name
    labels = {
      "pod-security.kubernetes.io/enforce"         = "restricted"
      "pod-security.kubernetes.io/enforce-version" = var.psa_version
      "pod-security.kubernetes.io/audit"           = "restricted"
      "pod-security.kubernetes.io/audit-version"   = var.psa_version
      "pod-security.kubernetes.io/warn"            = "restricted"
      "pod-security.kubernetes.io/warn-version"    = var.psa_version
    }
  }
}

resource "kubernetes_service_account_v1" "workload" {
  metadata {
    name      = var.service_account_name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  automount_service_account_token = false
}

resource "kubernetes_network_policy_v1" "default_deny" {
  metadata {
    name      = "default-deny"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
  }
}

resource "kubernetes_network_policy_v1" "dns" {
  metadata {
    name      = "allow-cluster-dns"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  spec {
    pod_selector {}
    policy_types = ["Egress"]
    egress {
      to {
        namespace_selector {
          match_labels = { "kubernetes.io/metadata.name" = "kube-system" }
        }
        pod_selector {
          match_labels = { "k8s-app" = "kube-dns" }
        }
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
  }
}

resource "kubernetes_resource_quota_v1" "workload" {
  metadata {
    name      = "workload-budget"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  spec {
    hard = {
      "pods"                   = "20"
      "requests.cpu"           = "4"
      "requests.memory"        = "8Gi"
      "limits.cpu"             = "8"
      "limits.memory"          = "16Gi"
      "services.loadbalancers" = "0"
      "services.nodeports"     = "0"
    }
  }
}
resource "kubernetes_limit_range_v1" "workload" {
  metadata {
    name      = "container-defaults"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  spec {
    limit {
      type            = "Container"
      default         = { cpu = "500m", memory = "256Mi" }
      default_request = { cpu = "100m", memory = "128Mi" }
    }
  }
}
