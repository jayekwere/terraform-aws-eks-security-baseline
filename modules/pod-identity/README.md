# Bounded Pod Identity S3 reader

Creates a Pod Identity role trusted by `pods.eks.amazonaws.com` for one exact cluster ARN, namespace and service account, plus an association. Permission is only `s3:GetObject` under `bucket_arn/object_prefix/*`; no list, write, KMS, STS delegation or arbitrary-policy input is available.

```hcl
module "reader" {
  source          = "../../modules/pod-identity"
  cluster_arn     = var.cluster_arn
  namespace       = "payments"
  service_account = "workload"
  bucket_arn      = "arn:aws:s3:::your-existing-development-bucket"
  object_prefix   = "reports/daily"
}
```

Requires a live same-account EKS cluster, agent, supported AWS SDK default credential chain and separately created service account. Keep session tags enabled. Default namespace egress blocks AWS access; design explicit agent TCP 80 (`169.254.170.23/32`) and private S3 endpoint TCP 443 paths, and verify actual CNI handling. IAM is additive; existing bucket/resource policies and administrators remain outside this narrow role contract. See [operations](../../docs/operations.md).
