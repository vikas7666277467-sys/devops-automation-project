variable "aws_region" {
  description = "AWS Region in which all resources are created."
  type        = string
  default     = "ap-south-1"
}

variable "key_pair_name" {
  description = "Name of an existing EC2 key pair in aws_region."
  type        = string

  validation {
    condition     = length(trimspace(var.key_pair_name)) > 0
    error_message = "key_pair_name must name an existing EC2 key pair."
  }
}

variable "trusted_cidr" {
  description = "Your public IPv4 address in CIDR form; controls SSH, HTTP, and Jenkins access."
  type        = string

  validation {
    condition     = can(cidrhost(var.trusted_cidr, 0)) && var.trusted_cidr != "0.0.0.0/0"
    error_message = "trusted_cidr must be a valid restricted CIDR and cannot be 0.0.0.0/0."
  }
}

variable "instance_type" {
  description = "EC2 instance type for both hosts. t3.medium is appropriate for a small Jenkins controller."
  type        = string
  default     = "t3.medium"
}

variable "root_volume_size" {
  description = "Encrypted gp3 root-volume size in GiB."
  type        = number
  default     = 30

  validation {
    condition     = var.root_volume_size >= 20
    error_message = "root_volume_size must be at least 20 GiB."
  }
}

variable "ecr_repository_name" {
  description = "Name of the private ECR repository."
  type        = string
  default     = "demoproject_ecr_repo1"
}

variable "project_name" {
  description = "Project identifier used in resource names and tags."
  type        = string
  default     = "demoproject_devops_project1"
}

variable "common_tags" {
  description = "Tags applied to all supported resources."
  type        = map(string)
  default = {
    Project   = "demoproject_devops_project1"
    ManagedBy = "Terraform"
    Purpose   = "DevOps-Training"
  }
}
