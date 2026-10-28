resource "aws_kms_key" "logs" {
  description             = "${var.name} control-plane logs only"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Sid       = "RootPolicyRecoveryOnly"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:PutKeyPolicy"
        Resource  = "*"
        Condition = { ArnEquals = { "aws:PrincipalArn" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" } }
      },
      {
        Sid       = "NamedKeyAdministration"
        Effect    = "Allow"
        Principal = { AWS = sort(tolist(var.log_key_admin_role_arns)) }
        Action = [
          "kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*", "kms:Put*",
          "kms:Update*", "kms:Revoke*", "kms:Disable*", "kms:Get*", "kms:Delete*",
          "kms:TagResource", "kms:UntagResource", "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion"
        ]
        Resource = "*"
      },
      {
        Sid       = "CloudWatchLogsForThisCluster"
        Effect    = "Allow"
        Principal = { Service = "logs.${data.aws_region.current.region}.amazonaws.com" }
        Action    = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
        Resource  = "*"
        Condition = {
          ArnEquals = { "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${var.name}/cluster" }
        }
      }
      ], length(var.log_reader_role_arns) == 0 ? [] : [{
        Sid       = "NamedAuditReadersViaLogsOnly"
        Effect    = "Allow"
        Principal = { AWS = sort(tolist(var.log_reader_role_arns)) }
        Action    = ["kms:Decrypt", "kms:DescribeKey"]
        Resource  = "*"
        Condition = {
          StringEquals = { "kms:ViaService" = "logs.${data.aws_region.current.region}.amazonaws.com" }
          ArnEquals    = { "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${var.name}/cluster" }
        }
    }])
  })
  tags = var.tags
  lifecycle {
    prevent_destroy = true
  }
}
