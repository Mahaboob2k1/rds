provider "aws" {
  region = var.region
}

# Assuming you have the IDs of your existing VPC, security group, and subnet group
data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_security_group" "existing_sg" {
  for_each = toset(var.security_group_ids)
  id       = each.value
}

data "aws_subnet" "selected" {
  for_each = toset(var.subnet_ids)
  id       = each.value
}

data "aws_availability_zones" "available" {}

# Create a KMS key for RDS encryption
resource "aws_kms_key" "rds_kms_key" {
  description             = "KMS key for RDS cluster encryption"
  deletion_window_in_days = 7

  tags = {
    Name = "rds-kms-key"
  }
}

resource "aws_kms_alias" "rds_kms_alias" {
  name          = "alias/rds-kms-key"
  target_key_id = aws_kms_key.rds_kms_key.id
}

# Create a parameter group for Aurora PostgreSQL Serverless v2
resource "aws_rds_cluster_parameter_group" "serverless_params" {
  name        = "aurora-postgresql-serverless-parameters"
  family      = "aurora-postgresql16"  # Ensure this matches your Aurora PostgreSQL engine version
  description = "Parameter group for Aurora PostgreSQL Serverless v2"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "0"
  }

  tags = {
    Name = "aurora-postgresql-serverless-parameters"
  }
}

# Create a subnet group with subnets in different availability zones
resource "aws_db_subnet_group" "main_subnet_group" {
  name       = var.subnet_group_name
  subnet_ids = var.subnet_ids

  tags = {
    Name = "my-db-subnet-group"
  }
}

# Create an Aurora Serverless v2 DB cluster
resource "aws_rds_cluster" "main_cluster" {
  cluster_identifier              = "my-aurora-cluster"
  engine                          = "aurora-postgresql"
  engine_version                  = "16.1"  # Ensure this matches the DBParameterGroupFamily specified
  database_name                   = var.db_name
  master_username                 = var.db_master_username
  master_password                 = var.db_master_password
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.serverless_params.name
  vpc_security_group_ids          = [for sg in data.aws_security_group.existing_sg : sg.id]
  db_subnet_group_name            = aws_db_subnet_group.main_subnet_group.name
  storage_encrypted               = true  # Ensure encryption is enabled
  kms_key_id                      = aws_kms_key.rds_kms_key.arn
  skip_final_snapshot             = true
  deletion_protection             = true
  allow_major_version_upgrade     = true  # Allow major version upgrades

  # Ensure the cluster uses subnets in multiple availability zones for high availability
  availability_zones = [
    data.aws_subnet.selected["subnet-0af4abb170dfe5d37"].availability_zone,
    data.aws_subnet.selected["subnet-0d44d9fd36a571855"].availability_zone,
    data.aws_subnet.selected["subnet-0411526bc70211453"].availability_zone,
  ]

  # Specify scaling configuration directly for Serverless v2
  serverlessv2_scaling_configuration {
    min_capacity = 1
    max_capacity = 16
  }

  # Enable CloudWatch Logs for PostgreSQL logs
  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = {
    Name = "my-aurora-cluster"
  }
}

# Create an AWS CloudWatch Logs group for PostgreSQL logs
resource "aws_cloudwatch_log_group" "postgresql_logs" {
  name = "/aws/rds/cluster/${aws_rds_cluster.main_cluster.cluster_identifier}/postgresql"

  tags = {
    Name = "RDS PostgreSQL Logs"
  }
}

# Create an Aurora Serverless v2 DB cluster instance
resource "aws_rds_cluster_instance" "main_instance" {
  cluster_identifier   = aws_rds_cluster.main_cluster.id
  instance_class       = "db.serverless"  # Placeholder; Serverless v2 does not use instance classes
  engine               = aws_rds_cluster.main_cluster.engine
  engine_version       = aws_rds_cluster.main_cluster.engine_version
  db_subnet_group_name = aws_db_subnet_group.main_subnet_group.name
  publicly_accessible  = false
  promotion_tier       = 1  # Set failover priority

  tags = {
    Name = "my-aurora-instance"
  }
}

