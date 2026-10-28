resource "aws_iam_role" "this" {
  name_prefix = "eks-object-reader-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
      Condition = { StringEquals = {
        "aws:RequestTag/eks-cluster-arn"            = var.cluster_arn
        "aws:RequestTag/kubernetes-namespace"       = var.namespace
        "aws:RequestTag/kubernetes-service-account" = var.service_account
      } }
    }]
  })
}
resource "aws_iam_role_policy" "read_objects" {
  role = aws_iam_role.this.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject"]
      Resource = ["${var.bucket_arn}/${var.object_prefix}/*"]
    }]
  })
}
resource "aws_eks_pod_identity_association" "this" {
  cluster_name    = split("/", var.cluster_arn)[1]
  namespace       = var.namespace
  service_account = var.service_account
  role_arn        = aws_iam_role.this.arn
  depends_on      = [aws_iam_role_policy.read_objects]
}
