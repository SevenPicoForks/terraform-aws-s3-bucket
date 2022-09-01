data "aws_caller_identity" "current" { count = local.enabled ? 1 : 0 }
data "aws_partition" "current" { count = local.enabled ? 1 : 0 }
data "aws_canonical_user_id" "default" { count = local.enabled ? 1 : 0 }

