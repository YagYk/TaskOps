# ECR Repository
resource "aws_ecr_repository" "taskops" {
  name                 = "taskops"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = "dev"
    Application = "taskops"
  }
}

# ECR lifecycle policy
resource "aws_ecr_lifecycle_policy" "taskops" {
  repository = aws_ecr_repository.taskops.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description   = "Keep last 10 images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

