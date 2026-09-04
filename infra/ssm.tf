resource "aws_ssm_parameter" "secret_key_base" {
  name  = "/${var.project_name}/SECRET_KEY_BASE"
  type  = "SecureString"
  value = var.secret_key_base
}
