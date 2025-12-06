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

# ============================================
# SSH Key Pair
# ============================================
resource "aws_key_pair" "azamat_key" {
  key_name   = "azamat-ec2-key"
  public_key = var.ssh_public_key
}

# ============================================
# IAM Role for EC2 - MINIMUM PERMISSIONS
# ============================================
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

# S3 Read-Only Policy
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

# ECR Pull Policy - for pulling Docker images
resource "aws_iam_role_policy" "ec2_ecr_policy" {
  name = "dog-sounds-ecr-pull-policy"
  role = aws_iam_role.ec2_s3_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# SSM Policy - for Systems Manager access (replaces SSH)
resource "aws_iam_role_policy_attachment" "ec2_ssm_policy" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch Logs Policy
resource "aws_iam_role_policy" "ec2_cloudwatch_policy" {
  name = "dog-sounds-cloudwatch-policy"
  role = aws_iam_role.ec2_s3_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/ec2/dog-sounds:*"
      }
    ]
  })
}

# Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "dog-sounds-ec2-profile"
  role = aws_iam_role.ec2_s3_role.name
}

# ============================================
# Security Group - HARDENED
# ============================================
resource "aws_security_group" "dog_sounds_sg" {
  name        = "dog-sounds-sg"
  description = "Security group for dog sounds web app - HARDENED"

  # HTTP - will redirect to HTTPS
  ingress {
    description = "HTTP (redirect to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH - RESTRICTED (backup only, use SSM instead)
  ingress {
    description = "SSH - Emergency access only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  # Egress - HTTPS only (no unrestricted outbound)
  egress {
    description = "HTTPS for package updates"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP for package repositories
  egress {
    description = "HTTP for package updates"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # DNS
  egress {
    description = "DNS"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # NTP for time sync
  egress {
    description = "NTP"
    from_port   = 123
    to_port     = 123
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dog-sounds-sg-hardened"
  }
}

# ============================================
# CloudWatch Log Group
# ============================================
resource "aws_cloudwatch_log_group" "dog_sounds" {
  name              = "/aws/ec2/dog-sounds"
  retention_in_days = 7

  tags = {
    Name = "dog-sounds-logs"
  }
}

# ============================================
# EC2 Instance - HARDENED
# ============================================
resource "aws_instance" "dog_sounds" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.azamat_key.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.dog_sounds_sg.id]

  # Enable detailed monitoring
  monitoring = true

  # IMDSv2 required (prevents SSRF attacks)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # EBS encryption
  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/user-data-hardened.sh", {
    ecr_repository_url = aws_ecr_repository.dog_sounds.repository_url
    aws_region         = var.aws_region
    docker_image_tag   = var.docker_image_tag
  })

  # Prevent accidental termination
  disable_api_termination = false

  tags = {
    Name        = "dog-sounds-app-hardened"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# ============================================
# Elastic IP
# ============================================
resource "aws_eip" "dog_sounds" {
  instance = aws_instance.dog_sounds.id
  domain   = "vpc"

  tags = {
    Name = "dog-sounds-eip"
  }
}

# ============================================
# Route 53 DNS Record
# ============================================
resource "aws_route53_record" "k9_watch" {
  zone_id = var.route53_zone_id
  name    = "k9-watch.azamat.rocks"
  type    = "A"
  ttl     = 300
  records = [aws_eip.dog_sounds.public_ip]
}

# ============================================
# CloudWatch Alarms
# ============================================

# CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "dog-sounds-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = []

  dimensions = {
    InstanceId = aws_instance.dog_sounds.id
  }
}

# Network Out Alarm (detect DDoS participation)
resource "aws_cloudwatch_metric_alarm" "high_network_out" {
  alarm_name          = "dog-sounds-high-network-out"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "NetworkOut"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 100000000 # 100MB
  alarm_description   = "Detects unusually high outbound traffic (potential DDoS)"
  alarm_actions       = []

  dimensions = {
    InstanceId = aws_instance.dog_sounds.id
  }
}

# ============================================
# Outputs
# ============================================
output "instance_public_ip" {
  value       = aws_eip.dog_sounds.public_ip
  description = "Elastic IP of the EC2 instance"
}

output "instance_id" {
  value       = aws_instance.dog_sounds.id
  description = "EC2 instance ID"
}

output "domain_name" {
  value       = aws_route53_record.k9_watch.fqdn
  description = "Domain name for the application"
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.dog_sounds.repository_url
  description = "ECR repository URL for pushing images"
}

output "ssm_connect_command" {
  value       = "aws ssm start-session --target ${aws_instance.dog_sounds.id} --region ${var.aws_region}"
  description = "Command to connect via AWS Systems Manager (no SSH needed)"
}
