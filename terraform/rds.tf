data "aws_caller_identity" "database" {}

data "aws_iam_policy_document" "database_kms" {
  #checkov:skip=CKV_AWS_111:KMS key policies require Resource star because the policy is attached to the key being created
  #checkov:skip=CKV_AWS_109:Account-root KMS administration is the recovery and IAM delegation principal
  #checkov:skip=CKV_AWS_356:KMS key policies do not support the not-yet-created key ARN as Resource
  statement {
    sid       = "AllowAccountKMSAdministration"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.database.account_id}:root"]
    }
  }
}
resource "aws_kms_key" "database" {
  description             = "KMS key for ${local.name_prefix} RDS storage, credentials, and Performance Insights"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.database_kms.json
  tags                    = local.common_tags
}

resource "aws_kms_alias" "database" {
  name          = "alias/${local.name_prefix}-database"
  target_key_id = aws_kms_key.database.key_id
}

data "aws_iam_policy_document" "rds_monitoring_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_monitoring" {
  name               = "${local.name_prefix}-rds-monitoring"
  assume_role_policy = data.aws_iam_policy_document.rds_monitoring_assume.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_parameter_group" "banking" {
  name   = "${local.name_prefix}-postgres18"
  family = "postgres18"

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "immediate"
  }

  parameter {
    name         = "log_statement"
    value        = "ddl"
    apply_method = "immediate"
  }

  parameter {
    name         = "log_min_duration_statement"
    value        = "1000"
    apply_method = "immediate"
  }

  tags = local.common_tags
}
resource "aws_db_subnet_group" "banking" {
  name       = "${local.name_prefix}-database"
  subnet_ids = module.vpc.private_subnets
  tags       = merge(local.common_tags, { Name = "${local.name_prefix}-database" })
}

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds"
  description = "PostgreSQL access from EKS managed nodes only"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-rds" })
}

resource "aws_db_instance" "banking" {
  identifier = "${local.name_prefix}-postgres"

  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  db_name  = var.db_name
  username = var.db_master_username
  port     = 5432

  manage_master_user_password         = true
  master_user_secret_kms_key_id       = aws_kms_key.database.arn
  iam_database_authentication_enabled = true

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.database.arn

  db_subnet_group_name   = aws_db_subnet_group.banking.name
  parameter_group_name   = aws_db_parameter_group.banking.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = var.db_multi_az

  backup_retention_period = var.db_backup_retention_days
  backup_window           = "02:00-03:00"
  maintenance_window      = "sun:03:00-sun:04:00"

  auto_minor_version_upgrade            = true
  copy_tags_to_snapshot                 = true
  deletion_protection                   = var.db_deletion_protection
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = aws_kms_key.database.arn
  performance_insights_retention_period = 7

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_monitoring.arn

  skip_final_snapshot       = var.db_skip_final_snapshot
  final_snapshot_identifier = var.db_skip_final_snapshot ? null : "${local.name_prefix}-postgres-final"

  apply_immediately = var.environment == "dev"

  tags = local.common_tags
}
