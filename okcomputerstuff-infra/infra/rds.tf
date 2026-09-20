resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnets"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnets"
  }
}

resource "aws_db_instance" "main" {
  identifier                  = "${var.project_name}-${var.environment}"
  engine                      = "mysql"
  engine_version              = "8.0"
  instance_class              = var.db_instance_class
  allocated_storage           = 20
  max_allocated_storage       = 100
  storage_type                = "gp3"
  storage_encrypted           = true
  db_name                     = var.db_name
  username                    = var.db_username
  manage_master_user_password = true
  port                        = 3306
  multi_az                    = false
  publicly_accessible         = false
  db_subnet_group_name        = aws_db_subnet_group.main.name
  vpc_security_group_ids      = [aws_security_group.rds.id]
  backup_retention_period     = var.db_backup_retention_period
  backup_window               = "18:00-19:00"
  maintenance_window          = "sun:19:00-sun:20:00"
  deletion_protection         = var.deletion_protection
  skip_final_snapshot         = var.skip_final_snapshot
  final_snapshot_identifier   = var.skip_final_snapshot ? null : "${var.project_name}-${var.environment}-final"
  apply_immediately           = false

  lifecycle {
    precondition {
      condition     = var.environment != "prod" || var.deletion_protection
      error_message = "Production RDS must have deletion protection enabled."
    }
    precondition {
      condition     = var.environment != "prod" || !var.skip_final_snapshot
      error_message = "Production RDS must retain a final snapshot on destroy."
    }
    precondition {
      condition     = var.environment != "prod" || var.db_backup_retention_period >= 1
      error_message = "Production RDS backup retention must be at least one day. AWS Free Tier accounts cannot retain more than one day."
    }
  }
}
