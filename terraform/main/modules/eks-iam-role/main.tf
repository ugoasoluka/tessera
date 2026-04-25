data "aws_iam_policy_document" "assume_role" {
  dynamic "statement" {
    for_each = var.assume_role_policies

    content {
      sid     = lookup(statement.value, "sid", null)
      effect  = lookup(statement.value, "effect", "Allow")
      actions = statement.value.actions

      dynamic "principals" {
        for_each = statement.value.principals

        content {
          type        = principals.value.type
          identifiers = principals.value.identifiers
        }
      }
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = toset(var.policy_attachments)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "this" {
  count = var.create_instance_profile ? 1 : 0
  name  = var.name
  role  = aws_iam_role.this.name
  tags  = var.tags
}