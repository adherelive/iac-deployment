terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # Uncomment this section if you want to use S3 for state management
  # backend "s3" {
  #   bucket = "adherelive-terraform-state"
  #   key    = "terraform.tfstate"
  #   region = "us-east-1"
  #   encrypt = true
  #   dynamodb_table = "adherelive-terraform-locks"
  # }
}