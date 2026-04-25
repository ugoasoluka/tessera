locals {
  secret_keys = [
    "slack-bot-token",
    "slack-app-token",
    "anthropic-api-key",
    "github-pat",
  ]
}

resource "aws_secretsmanager_secret" "app_secrets" {
  for_each = toset(local.secret_keys)

  name                    = "tessera/${each.key}"
  description             = "Tessera coding agent: ${each.key}"
  recovery_window_in_days = 0

  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "placeholder" {
  for_each = aws_secretsmanager_secret.app_secrets

  secret_id     = each.value.id
  secret_string = "PLACEHOLDER_REPLACE_ME"

  lifecycle {
    ignore_changes = [secret_string]
  }
}