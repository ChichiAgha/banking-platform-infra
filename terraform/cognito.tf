resource "aws_cognito_user_pool" "banking" {
  name = "${local.name_prefix}-users"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]
  mfa_configuration        = "OPTIONAL"

  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 1
  }

  software_token_mfa_configuration {
    enabled = true
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  user_pool_add_ons {
    advanced_security_mode = "AUDIT"
  }

  deletion_protection = "INACTIVE"

  tags = local.common_tags
}

resource "aws_cognito_user_pool_client" "banking_alb" {
  name         = "${local.name_prefix}-alb"
  user_pool_id = aws_cognito_user_pool.banking.id

  generate_secret                      = true
  prevent_user_existence_errors        = "ENABLED"
  supported_identity_providers         = ["COGNITO"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  callback_urls                        = ["https://${var.application_domain}/oauth2/idpresponse"]
  logout_urls                          = ["https://${var.application_domain}/"]

  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 1

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}

resource "aws_cognito_user_pool_domain" "banking" {
  domain       = "${var.project}-${var.environment}-${data.aws_caller_identity.database.account_id}"
  user_pool_id = aws_cognito_user_pool.banking.id
}
