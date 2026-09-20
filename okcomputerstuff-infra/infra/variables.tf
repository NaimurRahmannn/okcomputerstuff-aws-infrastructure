variable "aws_region" {
  description = "AWS region for the blog infrastructure."
  type        = string
  default     = "ap-southeast-1"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Short project name used in AWS resource names."
  type        = string
  default     = "okcomputerstuff"
}

variable "domain_name" {
  description = "Public domain already hosted in Route 53."
  type        = string
  default     = "example.com"
}

variable "vpc_cidr" {
  description = "CIDR range for the blog VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs for the ALB and NAT gateway subnets."
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs for the EC2 and RDS subnets."
  type        = list(string)
  default     = ["10.20.11.0/24", "10.20.12.0/24"]
}

variable "availability_zones" {
  description = "Two availability zones in aws_region."
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "app_instance_type" {
  description = "EC2 instance type for the blog application."
  type        = string
  default     = "t3.micro"
}

variable "db_instance_class" {
  description = "RDS instance class for MySQL."
  type        = string
  default     = "db.t3.micro"
}

variable "db_backup_retention_period" {
  description = "Number of days to retain automated RDS backups. Free Tier accounts are limited to 1 day; use 7 or more after upgrading the account."
  type        = number
  default     = 1

  validation {
    condition     = var.db_backup_retention_period >= 0 && var.db_backup_retention_period <= 35
    error_message = "db_backup_retention_period must be between 0 and 35 days."
  }
}

variable "db_name" {
  description = "Initial RDS database name."
  type        = string
  default     = "okcomputerstuff"
}

variable "db_username" {
  description = "RDS master username. The generated password is managed by RDS."
  type        = string
  default     = "blog_admin"
}

variable "skip_final_snapshot" {
  description = "Skip the final RDS snapshot when destroying non-production environments. Production is prevented from skipping it."
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Protect the RDS instance from deletion. Production is prevented from disabling it."
  type        = bool
  default     = true
}
