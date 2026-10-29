terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment and fill in to keep state in S3 with locking.
  # backend "s3" {
  #   bucket       = "<state-bucket>"
  #   key          = "canary-pipeline/terraform.tfstate"
  #   region       = "eu-west-1"
  #   use_lockfile = true
  # }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "canary-pipeline"
      ManagedBy = "terraform"
    }
  }
}
