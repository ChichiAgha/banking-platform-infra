resource "aws_acm_certificate" "application" {
  domain_name       = var.application_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}
