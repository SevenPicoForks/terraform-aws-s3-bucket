terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.97.0" # blocked_encryption_types support (April 2026 SSE-C change)
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.7"
    }
  }
}
