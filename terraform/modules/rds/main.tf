# ── DB Subnet Group (requires subnets in ≥2 AZs) ────────────────────────────
resource "aws_db_subnet_group" "main" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name      = "${var.identifier}-subnet-group"
    ManagedBy = "Terraform"
  }
}

# ── RDS Security Group (allow PostgreSQL from within VPC) ────────────────────
resource "aws_security_group" "rds" {
  name        = "${var.identifier}-rds-sg"
  description = "Allow PostgreSQL (5432) from EC2 instances in the VPC"
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "${var.identifier}-rds-sg"
    ManagedBy = "Terraform"
  }
}

# ── PostgreSQL Parameter Group ───────────────────────────────────────────────
resource "aws_db_parameter_group" "main" {
  name   = "${var.identifier}-pg15"
  family = "postgres15"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  tags = {
    Name      = "${var.identifier}-pg15"
    ManagedBy = "Terraform"
  }
}

# ── RDS PostgreSQL Instance ──────────────────────────────────────────────────
resource "aws_db_instance" "main" {
  identifier        = var.identifier
  engine         = "postgres"
  engine_version = "15.17"
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = "gp2"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.main.name

  multi_az               = false
  publicly_accessible    = false
  deletion_protection    = false
  skip_final_snapshot    = true

  backup_retention_period = 7
  backup_window           = "02:00-03:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  tags = {
    Name        = var.identifier
    ManagedBy   = "Terraform"
    Environment = "production"
  }
}

# ── Schema provisioner ───────────────────────────────────────────────────────
# Copies schema.sql to the EC2 bastion (which is inside the VPC and can reach
# RDS on port 5432) then applies it with psql.  Runs once after the DB is up;
# re-runs only when schema.sql changes (trigger on file hash).
resource "null_resource" "db_schema" {
  depends_on = [aws_db_instance.main]

  triggers = {
    schema_hash = filemd5("${path.module}/schema.sql")
    db_endpoint = aws_db_instance.main.endpoint
  }

  connection {
    type        = "ssh"
    host        = var.bastion_host
    user        = var.bastion_user
    private_key = file(var.bastion_private_key_path)
    timeout     = "5m"
  }

  # 1 — upload schema.sql to the bastion
  provisioner "file" {
    source      = "${path.module}/schema.sql"
    destination = "/tmp/pas_schema.sql"
  }

  # 2 — ensure psql client is installed, then run the schema
  provisioner "remote-exec" {
    inline = [
      "if ! command -v psql &>/dev/null; then sudo apt-get update -q && sudo apt-get install -yq postgresql-client; fi",
      "PGPASSWORD='${var.db_password}' psql -h ${aws_db_instance.main.address} -U ${var.db_username} -d ${var.db_name} -f /tmp/pas_schema.sql",
      "rm -f /tmp/pas_schema.sql"
    ]
  }
}
