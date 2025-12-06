# ECR Repository for secure container images
resource "aws_ecr_repository" "dog_sounds" {
  name                 = "dog-sounds-app"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "dog-sounds-ecr"
  }
}

# ECR Lifecycle Policy - keep only last 10 images
resource "aws_ecr_lifecycle_policy" "dog_sounds" {
  repository = aws_ecr_repository.dog_sounds.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.dog_sounds.repository_url
  description = "ECR repository URL for pushing images"
}
