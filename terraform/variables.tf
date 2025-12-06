variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small" # Enough for Docker + Nginx + Next.js
}

variable "ami_id" {
  description = "AMI ID for Ubuntu 22.04 LTS in us-east-1"
  type        = string
  default     = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS
}

variable "s3_bucket_name" {
  description = "S3 bucket name for dog sounds"
  type        = string
  default     = "frigate-dog-barks-azamat"
}

variable "ssh_public_key" {
  description = "SSH public key for EC2 access (can be RSA, ED25519, or ECDSA)"
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "CIDR block allowed for SSH access (your IP)"
  type        = string
  default     = "98.147.218.157/32"
}

variable "docker_image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
  default     = "Z088629523LTIHIM0NVQF"
}
