resource "aws_secretsmanager_secret" "app" {
  name                    = "${var.project_name}/${var.environment}/app"
  description             = "Runtime configuration for the okcomputerstuff application."
  recovery_window_in_days = 7
}
