mock_provider "aws" {
  override_during = plan
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111122223333", arn = "arn:aws:iam::111122223333:role/terraform", user_id = "MOCK" }
  }
  mock_data "aws_vpc" {
    defaults = { enable_dns_support = true, enable_dns_hostnames = true }
  }
  mock_data "aws_subnet" {
    defaults = { vpc_id = "vpc-0123456789abcdef0", map_public_ip_on_launch = false, availability_zone = "us-west-2a" }
  }
  mock_data "aws_route_table" {
    defaults = { routes = [] }
  }
  mock_data "aws_region" {
    defaults = { name = "us-west-2", region = "us-west-2" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws", dns_suffix = "amazonaws.com", reverse_dns_prefix = "com.amazonaws" }
  }
  mock_data "aws_iam_session_context" {
    defaults = { issuer_arn = "arn:aws:iam::111122223333:role/terraform" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_resource "aws_kms_key" {
    defaults = { arn = "arn:aws:kms:us-west-2:111122223333:key/12345678-1234-1234-1234-123456789012" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::111122223333:role/mock-role" }
  }
}
mock_provider "tls" {}
mock_provider "time" {}

override_data {
  target = data.aws_subnet.selected["subnet-1123456789abcdef0"]
  values = { vpc_id = "vpc-0123456789abcdef0", map_public_ip_on_launch = false, availability_zone = "us-west-2b" }
}

variables {
  name                          = "baseline-test"
  kubernetes_version            = "1.35"
  vpc_id                        = "vpc-0123456789abcdef0"
  private_subnet_ids            = ["subnet-0123456789abcdef0", "subnet-1123456789abcdef0"]
  api_client_security_group_ids = ["sg-0123456789abcdef0"]
  bootstrap_admin_role_arn      = "arn:aws:iam::111122223333:role/bootstrap"
  log_key_admin_role_arns       = ["arn:aws:iam::111122223333:role/terraform"]
  addon_versions = {
    vpc_cni            = "v1.21.1-eksbuild.1"
    pod_identity_agent = "v1.3.8-eksbuild.1"
    kube_proxy         = "v1.35.0-eksbuild.1"
  }
  namespace_viewers = {
    reader = { principal_arn = "arn:aws:iam::111122223333:role/viewer", namespaces = ["payments"] }
  }
}

run "secure_plan" {
  command = plan
  assert {
    condition     = aws_kms_key.logs.enable_key_rotation && aws_kms_key.logs.deletion_window_in_days == 30
    error_message = "Audit key rotation and deletion window regressed."
  }
  assert {
    condition     = jsondecode(aws_iam_role.cni.assume_role_policy).Statement[0].Condition.StringEquals["aws:RequestTag/eks-cluster-arn"] == "arn:aws:eks:us-west-2:111122223333:cluster/baseline-test"
    error_message = "CNI trust must bind the exact cluster ARN."
  }
}
run "reject_wildcard_namespace" {
  command = plan
  variables {
    namespace_viewers = { reader = { principal_arn = "arn:aws:iam::111122223333:role/viewer", namespaces = ["*"] } }
  }
  expect_failures = [var.namespace_viewers]
}
run "reject_implicit_admin_user" {
  command = plan
  variables { bootstrap_admin_role_arn = "arn:aws:iam::111122223333:user/admin" }
  expect_failures = [var.bootstrap_admin_role_arn]
}
run "reject_old_cni" {
  command = plan
  variables {
    addon_versions = { vpc_cni = "v1.14.0-eksbuild.3", pod_identity_agent = "v1.3.8-eksbuild.1", kube_proxy = "v1.35.0-eksbuild.1" }
  }
  expect_failures = [var.addon_versions]
}
run "reject_mutable_addon" {
  command = plan
  variables {
    addon_versions = { vpc_cni = "latest", pod_identity_agent = "v1.3.8-eksbuild.1", kube_proxy = "v1.35.0-eksbuild.1" }
  }
  expect_failures = [var.addon_versions]
}
run "reject_single_subnet" {
  command = plan
  variables { private_subnet_ids = ["subnet-0123456789abcdef0"] }
  expect_failures = [var.private_subnet_ids]
}
run "reject_duplicate_admin" {
  command = plan
  variables {
    namespace_viewers = { reader = { principal_arn = "arn:aws:iam::111122223333:role/bootstrap", namespaces = ["payments"] } }
  }
  expect_failures = [var.namespace_viewers]
}
run "reject_public_subnet" {
  command = plan
  override_data {
    target = data.aws_subnet.selected["subnet-1123456789abcdef0"]
    values = { vpc_id = "vpc-0123456789abcdef0", map_public_ip_on_launch = true, availability_zone = "us-west-2b" }
  }
  expect_failures = [terraform_data.network_prerequisites]
}
run "reject_disabled_private_dns" {
  command = plan
  override_data {
    target = data.aws_vpc.selected
    values = { enable_dns_support = false, enable_dns_hostnames = false }
  }
  expect_failures = [terraform_data.network_prerequisites]
}
run "reject_single_az" {
  command = plan
  override_data {
    target = data.aws_subnet.selected["subnet-1123456789abcdef0"]
    values = { vpc_id = "vpc-0123456789abcdef0", map_public_ip_on_launch = false, availability_zone = "us-west-2a" }
  }
  expect_failures = [terraform_data.network_prerequisites]
}
run "reject_wrong_vpc" {
  command = plan
  override_data {
    target = data.aws_subnet.selected["subnet-1123456789abcdef0"]
    values = { vpc_id = "vpc-99999999999999999", map_public_ip_on_launch = false, availability_zone = "us-west-2b" }
  }
  expect_failures = [terraform_data.network_prerequisites]
}
run "reject_internet_gateway_route" {
  command = plan
  override_data {
    target = data.aws_route_table.selected["subnet-1123456789abcdef0"]
    values = { routes = [{ cidr_block = "0.0.0.0/0", gateway_id = "igw-0123456789abcdef0" }] }
  }
  expect_failures = [terraform_data.network_prerequisites]
}
