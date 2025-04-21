terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Uncomment this block to use S3 backend for state storage
  # backend "s3" {
  #   bucket = "terraform-state"
  #   key    = "snackbar-management-queue/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = local.region
}
