# ------------------------------------------------------------------------------
# TFState Storage Context
# ------------------------------------------------------------------------------
module "tfstate_storage_context" {
  source     = "SevenPico/context/null"
  version    = "2.0.0"
  context    = module.context.self
  attributes = var.attributes_override == null ? ["tfstate"] : var.attributes_override
}


# ------------------------------------------------------------------------------
# TFState Storage IAM Policy
# ------------------------------------------------------------------------------
locals {
  s3_bucket_arn = "arn:${data.aws_partition.current.partition}:s3:::${module.tfstate_storage_context.id}"
  bucket_name   = var.bucket_name == null || var.bucket_name == "" ? module.context.id : var.bucket_name
}

data "aws_iam_policy_document" "tfstate_storage" {
  count = module.tfstate_storage_context.enabled ? 1 : 0

}


# ------------------------------------------------------------------------------
# TFState Storage
# ------------------------------------------------------------------------------
module "tfstate_storage" {
  source  = "../../"
  context = module.tfstate_storage_context.self

  acl                          = "private"
  allow_encrypted_uploads_only = false
  allow_ssl_requests_only      = true
  allowed_bucket_actions = [
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
  bucket_name                   = local.bucket_name
  cors_rule_inputs              = null
  enable_mfa_delete             = var.enable_mfa_delete
  force_destroy                 = var.force_destroy
  grants                        = []
  ignore_public_acls            = true
  kms_master_key_arn            = module.kms_key.key_arn
  lifecycle_configuration_rules = var.lifecycle_configuration_rules
  logging = var.access_log_bucket_name != null && var.access_log_bucket_name != "" ? {
    bucket_name = var.access_log_bucket_name
    prefix      = var.access_log_bucket_prefix_override == null ? "${join("", data.aws_caller_identity.current[*].account_id)}/${module.context.id}/" : (var.access_log_bucket_prefix_override != "" ? "${var.access_log_bucket_prefix_override}/" : "")
  } : null
  object_lock_configuration    = null
  privileged_principal_actions = []
  privileged_principal_arns    = []
  restrict_public_buckets      = true
  s3_object_ownership          = var.s3_object_ownership
  s3_replica_bucket_arn        = var.s3_replica_bucket_arn
  s3_replication_enabled       = var.s3_replication_enabled
  s3_replication_rules         = var.s3_replication_rules
  s3_replication_source_roles  = var.s3_replication_source_roles
  source_policy_documents = concat([
    one(data.aws_iam_policy_document.tfstate_storage[*].json)
  ], var.s3_source_policy_documents)
  sse_algorithm                 = module.kms_key.alias_arn == "" ? "AES256" : "aws:kms"
  transfer_acceleration_enabled = false
  user_enabled                  = false
  versioning_enabled            = var.enable_versioning
  wait_time_seconds             = 45
  website_inputs                = null

}
