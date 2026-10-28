data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  cluster_arn = "arn:aws:eks:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:cluster/${var.name}"
  access_entries = merge({
    bootstrap = {
      principal_arn = var.bootstrap_admin_role_arn
      policy_associations = {
        administrator = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
    }, { for key, viewer in var.namespace_viewers : "viewer-${key}" => {
      principal_arn = viewer.principal_arn
      policy_associations = {
        view = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
          access_scope = {
            type       = "namespace"
            namespaces = sort(tolist(viewer.namespaces))
          }
        }
      }
    }
  })
}

module "eks" {
  # terraform-aws-modules/eks/aws v21.29.0, resolved to an immutable commit.
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-eks.git?ref=91f11ea01656c26b8e6b8eb1b74f19863f60056c"

  name               = var.name
  kubernetes_version = var.kubernetes_version
  vpc_id             = var.vpc_id
  subnet_ids         = terraform_data.network_prerequisites.output
  ip_family          = "ipv4"

  endpoint_private_access                  = true
  endpoint_public_access                   = false
  endpoint_public_access_cidrs             = []
  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = false
  access_entries                           = local.access_entries
  deletion_protection                      = var.deletion_protection
  upgrade_policy                           = { support_type = "STANDARD" }

  enabled_log_types                      = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_log_group_retention_in_days = 90
  cloudwatch_log_group_kms_key_id        = aws_kms_key.logs.arn
  cloudwatch_log_group_class             = "STANDARD"
  create_kms_key                         = false
  encryption_config                      = null
  attach_encryption_policy               = false
  enable_irsa                            = false

  security_group_additional_rules = { for sg in var.api_client_security_group_ids : sg => {
    description              = "Approved private API client"
    protocol                 = "tcp"
    from_port                = 443
    to_port                  = 443
    type                     = "ingress"
    source_security_group_id = sg
  } }

  addons = {
    eks-pod-identity-agent = {
      before_compute = true
      addon_version  = var.addon_versions.pod_identity_agent
      most_recent    = false
      preserve       = false
    }
    vpc-cni = {
      before_compute = true
      addon_version  = var.addon_versions.vpc_cni
      most_recent    = false
      preserve       = false
      configuration_values = jsonencode({
        enableNetworkPolicy = "true"
        env                 = { NETWORK_POLICY_ENFORCING_MODE = "strict" }
      })
      pod_identity_association = [{
        role_arn        = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role_policy_attachment.cni.role}"
        service_account = "aws-node"
      }]
    }
    kube-proxy = {
      addon_version = var.addon_versions.kube_proxy
      most_recent   = false
      preserve      = false
    }
  }

  eks_managed_node_groups = {
    baseline = {
      ami_type                   = "AL2023_x86_64_STANDARD"
      instance_types             = var.node_instance_types
      min_size                   = 2
      max_size                   = 3
      desired_size               = 2
      iam_role_attach_cni_policy = false
      create_iam_role            = false
      iam_role_arn = one(distinct([
        for p in aws_iam_role_policy_attachment.nodes : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${p.role}"
      ]))
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 1
        instance_metadata_tags      = "disabled"
      }
      block_device_mappings = {
        root = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 30
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }
      update_config = { max_unavailable = 1 }
    }
  }

  tags = var.tags
}

resource "aws_iam_role" "cni" {
  name_prefix = "${var.name}-cni-"
  description = "IPv4 VPC CNI only; not attached to node roles"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
      Condition = { StringEquals = {
        "aws:RequestTag/eks-cluster-arn"            = local.cluster_arn
        "aws:RequestTag/kubernetes-namespace"       = "kube-system"
        "aws:RequestTag/kubernetes-service-account" = "aws-node"
      } }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cni" {
  role       = aws_iam_role.cni.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
