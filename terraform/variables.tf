variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"  # Enough for Docker + Nginx + Next.js
}

variable "ami_id" {
  description = "AMI ID for Ubuntu 22.04 LTS in us-east-1"
  type        = string
  default     = "ami-0c7217cdde317cfec"  # Ubuntu 22.04 LTS
}

# Removed - using aws_key_pair resource instead

variable "s3_bucket_name" {
  description = "S3 bucket name for dog sounds"
  type        = string
  default     = "frigate-dog-barks-azamat"
}

variable "ssh_public_key" {
  description = "SSH public key for EC2 access (can be RSA, ED25519, or ECDSA)"
  type        = string
}
