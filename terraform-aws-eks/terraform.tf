terraform {
  required_version = ">= 1.5.0"
  backend "s3" {
     bucket = "tfstate-bucket-grizzell-2026"
    key    = "dev/terraform.state"
    region = "us-west-2" # Variables aren't allowed here *shrug*
    dynamodb_table = "terraform-locks"
    encrypt = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}