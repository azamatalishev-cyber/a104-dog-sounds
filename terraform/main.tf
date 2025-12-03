terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Import your SSH public key
resource "aws_key_pair" "azamat_key" {
  key_name   = "azamat-ec2-key"
  public_key = var.ssh_public_key
}

# IAM Role for EC2 to access S3
resource "aws_iam_role" "ec2_s3_role" {
  name = "dog-sounds-ec2-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for S3 Read Access
resource "aws_iam_role_policy" "ec2_s3_policy" {
  name = "dog-sounds-s3-read-policy"
  role = aws_iam_role.ec2_s3_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      }
    ]
  })
}

# Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "dog-sounds-ec2-profile"
  role = aws_iam_role.ec2_s3_role.name
}

# Security Group
resource "aws_security_group" "dog_sounds_sg" {
  name        = "dog-sounds-sg"
  description = "Security group for dog sounds web app"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["98.147.218.157/32"]  # Only allow SSH from your Mac
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dog-sounds-sg"
  }
}

# EC2 Instance
resource "aws_instance" "dog_sounds" {
  ami                    = var.ami_id  # Ubuntu 22.04 LTS
  instance_type          = var.instance_type
  key_name              = aws_key_pair.azamat_key.key_name
  iam_instance_profile  = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.dog_sounds_sg.id]

  user_data = templatefile("${path.module}/user-data.sh", {
    s3_bucket_name = var.s3_bucket_name
    aws_region     = var.aws_region
  })

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "dog-sounds-app"
  }
}

# Elastic IP
resource "aws_eip" "dog_sounds" {
  instance = aws_instance.dog_sounds.id
  domain   = "vpc"

  tags = {
    Name = "dog-sounds-eip"
  }
}

# Route 53 DNS Record
resource "aws_route53_record" "k9_watch" {
  zone_id = "Z088629523LTIHIM0NVQF"
  name    = "k9-watch.azamat.rocks"
  type    = "A"
  ttl     = 300
  records = [aws_eip.dog_sounds.public_ip]
}

output "instance_public_ip" {
  value       = aws_eip.dog_sounds.public_ip
  description = "Elastic IP of the EC2 instance"
}

output "instance_public_dns" {
  value       = aws_instance.dog_sounds.public_dns
  description = "Public DNS of the EC2 instance"
}

output "domain_name" {
  value       = aws_route53_record.k9_watch.fqdn
  description = "Domain name for the application"
}
