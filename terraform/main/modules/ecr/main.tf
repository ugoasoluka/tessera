resource "aws_ecr_repository" "ecr_repository" {
  name                 = "${var.project_family}-${var.name}"
  image_tag_mutability = var.image_tag_mutability
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = var.tags
}

data "aws_ecr_lifecycle_policy_document" "lifecycle_policy_data" {
  rule {
    priority    = 1
    description = "Keep the most recent 10 images"

    selection {
      tag_status   = "any"
      count_type   = "imageCountMoreThan"
      count_number = 10
    }

    action {
      type = "expire"
    }
  }
}

resource "aws_ecr_lifecycle_policy" "ecr_policy" {
  count      = var.apply_lfc_policy ? 1 : 0
  repository = aws_ecr_repository.ecr_repository.name
  policy     = data.aws_ecr_lifecycle_policy_document.lifecycle_policy_data.json
}