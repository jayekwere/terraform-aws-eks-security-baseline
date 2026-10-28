output "role_arn" {
  description = "GetObject-only workload role; no bucket listing, writes or KMS decryption."
  value       = aws_iam_role.this.arn
}
