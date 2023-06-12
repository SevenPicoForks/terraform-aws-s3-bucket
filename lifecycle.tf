locals {
  # full_lifecycle_rule_schema is just for documentation, not actually used.
  full_lifecycle_rule_schema = {
    enabled = true # bool
    id      = null # string, must be specified and unique

    abort_incomplete_multipart_upload_days = var.abort_incomplete_multipart_upload_days # number
    filter_prefix_only                     = null # string See https://github.com/hashicorp/terraform-provider-aws/issues/23882
    filter_and = {
      object_size_greater_than = null # integer >= 0
      object_size_less_than    = null # integer >= 1
      prefix                   = null # string
      tags                     = {}   # map(string)
    }
    expiration = {
      date                         = null # string
      days                         = null # integer > 0
      expired_object_delete_marker = null # bool
    }
    noncurrent_version_expiration = {
      newer_noncurrent_versions = null # integer > 0
      noncurrent_days           = null # integer >= 0
    }
    transition = [{
      date          = null # string
      days          = null # integer >= 0
      storage_class = null # string/enum, one of GLACIER, STANDARD_IA, ONEZONE_IA, INTELLIGENT_TIERING, DEEP_ARCHIVE, GLACIER_IR.
    }]
    noncurrent_version_transition = [{
      newer_noncurrent_versions = null # integer >= 0
      noncurrent_days           = null # integer >= 0
      storage_class             = null # string/enum, one of GLACIER, STANDARD_IA, ONEZONE_IA, INTELLIGENT_TIERING, DEEP_ARCHIVE, GLACIER_IR.
    }]
  }

  lifecycle_configuration_rules = var.lifecycle_configuration_rules == null ? [] : var.lifecycle_configuration_rules
  # Normalize the input, filling in missing fields
  normalized_lifecycle_configuration_rules = [for rule in local.lifecycle_configuration_rules : {
    enabled = rule.enabled
    id      = rule.id

    abort_incomplete_multipart_upload_days = rule.abort_incomplete_multipart_upload_days # number

    # Due to https://github.com/hashicorp/terraform-provider-aws/issues/23882
    # we have to treat having only the `prefix` set differently than having any other setting.
    filter_prefix_only = (try(rule.filter_and.object_size_greater_than, null) == null &&
      try(rule.filter_and.object_size_less_than, null) == null &&
      try(length(rule.filter_and.tags), 0) == 0 &&
    try(length(rule.filter_and.prefix), 0) > 0) ? rule.filter_and.prefix : null

    filter_and = (try(rule.filter_and.object_size_greater_than, null) == null &&
      try(rule.filter_and.object_size_less_than, null) == null &&
      try(length(rule.filter_and.tags), 0) == 0) ? null : {
      object_size_greater_than = try(rule.filter_and.object_size_greater_than, null)
      object_size_less_than    = try(rule.filter_and.object_size_less_than, null)
      prefix                   = try(length(rule.filter_and.prefix), 0) == 0 ? null : rule.filter_and.prefix
      tags                     = try(length(rule.filter_and.tags), 0) == 0 ? {} : rule.filter_and.tags
    }
    # We use "!= true" because it covers !null as well as !false, and allows the "null" option to be on the same line.
    expiration = (try(rule.expiration.date, null) == null &&
      try(rule.expiration.days, null) == null &&
      try(rule.expiration.expired_object_delete_marker, null) == null) ? null : {
      date = try(rule.expiration.date, null)
      days = try(rule.expiration.days, null)

      expired_object_delete_marker = try(rule.expiration.expired_object_delete_marker, null)
    }
    noncurrent_version_expiration = (try(rule.noncurrent_version_expiration.noncurrent_days, null) == null &&
      try(rule.noncurrent_version_expiration.newer_noncurrent_versions, null) == null) ? null : {
      newer_noncurrent_versions = try(rule.noncurrent_version_expiration.newer_noncurrent_versions, null)
      noncurrent_days           = try(rule.noncurrent_version_expiration.noncurrent_days, null)
    }
    transition = rule.transition == null ? [] : [for t in rule.transition : {
      date          = try(t.date, null)
      days          = try(t.days, null)
      storage_class = t.storage_class
    } if try(t.date, null) != null || try(t.days, null) != null]
    noncurrent_version_transition = rule.noncurrent_version_transition == null ? [] : [
      for t in rule.noncurrent_version_transition :
      {
        newer_noncurrent_versions = try(t.newer_noncurrent_versions, null)
        noncurrent_days           = try(t.noncurrent_days, null)
        storage_class             = t.storage_class
      } if try(t.newer_noncurrent_versions, null) != null || try(t.noncurrent_days, null) != null
    ]
  }]

  lc_rules = local.normalized_lifecycle_configuration_rules
}


resource "aws_s3_bucket_lifecycle_configuration" "default" {
  count  = local.enabled && length(local.lc_rules) > 0 ? 1 : 0
  bucket = join("", aws_s3_bucket.default.*.id)

  dynamic "rule" {
    for_each = local.lc_rules

    content {
      id     = rule.value.id
      status = rule.value.enabled == true ? "Enabled" : "Disabled"

      # Filter is always required due to https://github.com/hashicorp/terraform-provider-aws/issues/23299
      dynamic "filter" {
        for_each = rule.value.filter_prefix_only == null && rule.value.filter_and == null ? ["empty"] : []
        content {}
      }

      # When only specifying `prefix`, do not use `and` due to https://github.com/hashicorp/terraform-provider-aws/issues/23882
      dynamic "filter" {
        for_each = rule.value.filter_prefix_only == null ? [] : ["prefix"]
        content {
          prefix = rule.value.filter_prefix_only
        }
      }

      # When specifying more than 1 filter criterion, use `and`
      dynamic "filter" {
        for_each = rule.value.filter_and == null ? [] : ["and"]
        content {
          and {
            object_size_greater_than = rule.value.filter_and.object_size_greater_than
            object_size_less_than    = rule.value.filter_and.object_size_less_than
            prefix                   = rule.value.filter_and.prefix
            tags                     = rule.value.filter_and.tags
          }
        }
      }

      dynamic "abort_incomplete_multipart_upload" {
        for_each = rule.value.abort_incomplete_multipart_upload_days == null ? [] : [1]
        content {
          days_after_initiation = rule.value.abort_incomplete_multipart_upload_days
        }
      }

      dynamic "expiration" {
        for_each = rule.value.expiration == null ? [] : [rule.value.expiration]
        content {
          date                         = expiration.value.date
          days                         = expiration.value.days
          expired_object_delete_marker = expiration.value.expired_object_delete_marker
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_version_expiration == null ? [] : [rule.value.noncurrent_version_expiration]
        iterator = expiration
        content {
          newer_noncurrent_versions = expiration.value.newer_noncurrent_versions
          noncurrent_days           = expiration.value.noncurrent_days
        }
      }

      dynamic "transition" {
        for_each = rule.value.transition

        content {
          date          = transition.value.date
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }

      dynamic "noncurrent_version_transition" {
        for_each = rule.value.noncurrent_version_transition
        iterator = transition
        content {
          newer_noncurrent_versions = transition.value.newer_noncurrent_versions
          noncurrent_days           = transition.value.noncurrent_days
          storage_class             = transition.value.storage_class
        }
      }
    }
  }

  depends_on = [
    # versioning must be set before lifecycle configuration
    aws_s3_bucket_versioning.default
  ]
}

