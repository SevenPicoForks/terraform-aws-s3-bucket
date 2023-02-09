# ------------------------------------------------------------------------------
# Build Artifacts Context
# ------------------------------------------------------------------------------
module "build_artifacts_context" {
  source     = "app.terraform.io/SevenPico/context/null"
  version    = "1.1.0"
  context    = module.context.self
  attributes = ["build-artifacts"]
}


# ------------------------------------------------------------------------------
# Build Artifacts IAM Policy
# ------------------------------------------------------------------------------
locals {
  s3_bucket_arn = "arn:${data.aws_partition.current.partition}:s3:::${module.build_artifacts_context.id}"
}

data "aws_iam_policy_document" "build_artifacts" {
  count = module.build_artifacts_context.enabled ? 1 : 0

}


# ------------------------------------------------------------------------------
# Build Artifacts
# ------------------------------------------------------------------------------
module "build_artifacts" {
  source  = "../../"
  context = module.build_artifacts_context.self

  acl                          = "private"
  allow_encrypted_uploads_only = false
  allow_ssl_requests_only      = true
  allowed_bucket_actions       = [
    "s3:PutObject",
    "s3:PutObjectAcl",
    "s3:GetObject",
    "s3:DeleteObject",
    "s3:ListBucket",
    "s3:ListBucketMultipartUploads",
    "s3:GetBucketLocation",
    "s3:AbortMultipartUpload"
  ]
  block_public_acls             = true
  block_public_policy           = true
  bucket_key_enabled            = false
  bucket_name                   = ""
  cors_rule_inputs              = []
  enable_mfa_delete             = var.enable_mfa_delete
  force_destroy                 = var.force_destroy
  ignore_public_acls            = true
  kms_master_key_arn            = module.kms_key.key_arn
  lifecycle_configuration_rules = var.lifecycle_configuration_rules
  logging                       = var.access_log_bucket_name != null && var.access_log_bucket_name != "" ? {
    bucket_name = var.access_log_bucket_name
    prefix      = var.access_log_bucket_prefix_override == null ? "${join("", data.aws_caller_identity.current[*].account_id)}/${module.context.id}/" : (var.access_log_bucket_prefix_override != "" ? "${var.access_log_bucket_prefix_override}/" : "")
  } : null
  object_lock_configuration    = null
  privileged_principal_actions = var.privileged_principal_actions
  privileged_principal_arns    = var.privileged_principal_arns
  restrict_public_buckets      = true
  s3_object_ownership          = var.s3_object_ownership
  s3_replica_bucket_arn        = var.s3_replica_bucket_arn
  s3_replication_enabled       = var.s3_replication_enabled
  s3_replication_rules         = var.s3_replication_rules
  s3_replication_source_roles  = var.s3_replication_source_roles
  source_policy_documents      = concat([
    one(data.aws_iam_policy_document.build_artifacts[*].json)
  ], var.s3_source_policy_documents)
  sse_algorithm                 = module.kms_key.alias_arn == "" ? "AES256" : "aws:kms"
  transfer_acceleration_enabled = false
  user_enabled                  = false
  versioning_enabled            = var.enable_versioning
  wait_time_seconds             = 45
  website_inputs                = []
}
