## AWS provider
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.61.0"
    }
    azurerm = {
      source = "hashicorp/azurerm"
      version = "=3.13.0"
    }
    digitalocean = {
      source = "digitalocean/digitalocean"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

}


provider "aws" {
  region 	= var.region 
}

provider "azurerm" {
   features {}
}

provider "digitalocean" {
  token = var.do_token
}

provider "random" {}
