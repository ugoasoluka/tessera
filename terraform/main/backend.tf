terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "ugo-tessera-tfstate"
    key            = "main/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "ugo-tessera-tflock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
}

locals {
  tags = {
    Project   = "tessera-takehome"
    ManagedBy = "terraform"
    Owner     = "Ugo-Asoluka"
  }
}