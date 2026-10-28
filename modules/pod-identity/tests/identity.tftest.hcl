mock_provider "aws" {
  override_during = plan
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::111122223333:role/object-reader" }
  }
}
variables {
  cluster_arn     = "arn:aws:eks:us-west-2:111122223333:cluster/baseline-test"
  namespace       = "payments"
  service_account = "report-reader"
  bucket_arn      = "arn:aws:s3:::example-reports"
  object_prefix   = "reports/daily"
}
run "bounded_reader" {
  command = plan
  assert {
    condition     = tomap(jsondecode(aws_iam_role.this.assume_role_policy).Statement[0].Condition.StringEquals) == tomap({ "aws:RequestTag/eks-cluster-arn" = var.cluster_arn, "aws:RequestTag/kubernetes-namespace" = var.namespace, "aws:RequestTag/kubernetes-service-account" = var.service_account })
    error_message = "Trust must bind cluster ARN, namespace and service account exactly."
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.read_objects.policy).Statement[0].Action == ["s3:GetObject"] && jsondecode(aws_iam_role_policy.read_objects.policy).Statement[0].Resource == ["arn:aws:s3:::example-reports/reports/daily/*"]
    error_message = "Reader must grant only GetObject within the explicit prefix."
  }
}
run "reject_bucket_wildcard" {
  command = plan
  variables { bucket_arn = "arn:aws:s3:::*" }
  expect_failures = [var.bucket_arn]
}
run "reject_prefix_wildcard" {
  command = plan
  variables { object_prefix = "reports/*" }
  expect_failures = [var.object_prefix]
}
run "reject_empty_prefix" {
  command = plan
  variables { object_prefix = "" }
  expect_failures = [var.object_prefix]
}
run "reject_cross_cluster_wildcard" {
  command = plan
  variables { cluster_arn = "arn:aws:eks:us-west-2:111122223333:cluster/*" }
  expect_failures = [var.cluster_arn]
}
