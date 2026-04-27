variable "identifier" {
  description = "RDS instance identifier"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block — used to allow EC2 → RDS traffic"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the DB subnet group (min 2)"
  type        = list(string)
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "pas_saas"
}

variable "db_username" {
  description = "Master DB username"
  type        = string
}

variable "db_password" {
  description = "Master DB password (sensitive)"
  type        = string
  sensitive   = true
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.4"
}

variable "bastion_host" {
  description = "Public IP of EC2 instance used as bastion to run schema migrations"
  type        = string
  default     = "18.135.45.32"
}

variable "bastion_user" {
  description = "SSH user for the bastion EC2 instance"
  type        = string
  default     = "ubuntu"
}

variable "bastion_private_key_path" {
  description = "Local path to the PEM key for SSH into the bastion"
  type        = string
  default     = "webkey.pem"
}
