terraform {

  backend "s3" {
    bucket = "scott-grizzell-tf-state-bucket-2026"
    key    = "dev/terraform.state"
    region = "us-west-2"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  required_version = ">= 1.5.0"
}