variable "bucket_name" {
  type        = string
  description = "Legacy input retained for compatibility; the S3 backend bucket is configured in remote_backend_s3.tf"
}

variable "domain_name" {
  type        = string
  description = "Public Jenkins hostname. Keep the real value in the ignored tfvars file."
  default     = "jenkins.example.com"
}

variable "hosted_zone_name" {
  type        = string
  description = "Route 53 public hosted zone containing domain_name."
  default     = "example.com"
}

variable "vpc_cidr" {
  type        = string
  description = "Public Subnet CIDR values"
}

variable "vpc_name" {
  type        = string
  description = "DevOps Project 1 VPC 1"
}

variable "cidr_public_subnet" {
  type        = list(string)
  description = "Public Subnet CIDR values"
}

variable "cidr_private_subnet" {
  type        = list(string)
  description = "Private Subnet CIDR values"
}

variable "availability_zone" {
  type        = list(string)
  description = "Availability Zones"
}

variable "public_key" {
  type        = string
  description = "DevOps Project 1 Public key for EC2 instance"
}

variable "ec2_ami_id" {
  type        = string
  description = "DevOps Project 1 AMI Id for EC2 instance"
}

variable "admin_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks allowed to SSH to Jenkins. Leave empty to disable direct SSH."
  default     = []

  validation {
    condition     = alltrue([for cidr in var.admin_cidr_blocks : can(cidrhost(cidr, 0)) && endswith(cidr, "/32")])
    error_message = "admin_cidr_blocks must contain only valid IPv4 /32 administrator addresses."
  }
}
