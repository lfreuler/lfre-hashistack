# main.tf - Nur Provider und Variables
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}

# variables.tf
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "cluster_name" {
  description = "Name of the cluster"
  type        = string
  default     = "hashicorp-demo"
}

variable "vpc_id" {
  description = "Existing VPC ID"
  type        = string
}

variable "private_subnet_id" {
  description = "Existing private subnet ID"
  type        = string
}

variable "public_subnet_id" {
  description = "Existing public subnet ID"
  type        = string
}

# Data sources für existierende Netzwerk-Ressourcen
data "aws_vpc" "existing" {
  id = var.vpc_id
}

data "aws_subnet" "private" {
  id = var.private_subnet_id
}

data "aws_subnet" "public" {
  id = var.public_subnet_id
}