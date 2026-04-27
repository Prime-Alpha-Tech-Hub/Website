
# Define the networking module
module "networking" {
  source             = "./modules/network/"
  vpc_name           = "nc-ce-load-balancing-vpc"
  cidr_range         = "10.0.0.0/20"
  availability_zones = var.availability_zones   # ← defined in root variables.tf
  public_subnets     = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets    = ["10.0.8.0/24", "10.0.9.0/24", "10.0.10.0/24"]
  target = module.ec2.instance_id[0]
  acm_certificate_arn = var.acm_certificate_arn
  }
# Define the EC2 module
module "ec2" {
  source   = "./modules/app"
  subnet    = module.networking.public_subnets[0] 
  security = [module.networking.alb_security_group_id]  # Pass security group ID as a list
}

resource "aws_route53_record" "app" {
  zone_id = "Z069844120BD3FPDOUVD2"
  name    = "app.primealphasecurities.com"
  type    = "A"

  alias {
    name                   = module.networking.alb_dns_name   # adjust to your output
    zone_id                = module.networking.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = module.networking.alb_target_group_arn
  target_id        = module.ec2.instance_id[0]   # ← add [0]
  port             = 80
}

resource "aws_route53_record" "root" {
  zone_id = "Z069844120BD3FPDOUVD2"
  name    = "primealphasecurities.com"
  type    = "A"

  alias {
    name                   = module.networking.alb_dns_name
    zone_id                = module.networking.alb_zone_id
    evaluate_target_health = true
  }
}

# # ── RDS PostgreSQL (replaces DynamoDB) ───────────────────────────────────────
# module "rds" {
#   source = "./modules/rds"

#   identifier = "pas-saas-db"
#   vpc_id     = "vpc-097399b9d9932aced"
#   vpc_cidr   = "10.0.0.0/20"

#   # Existing private subnets (10.0.8-10/24 range, eu-west-2b/a/c)
#   private_subnet_ids = [
#     "subnet-032da43d930d1d797",
#     "subnet-068d202c68ca936fc",
#     "subnet-06ec1565a3115fbee",
#   ]

#   db_name           = "pas_saas"
#   db_username       = var.db_username
#   db_password       = var.db_password
#   instance_class    = "db.t3.micro"
#   allocated_storage = 20
#   engine_version    = "15.4"

#   # Bastion SSH — EC2 is inside the VPC and can reach RDS port 5432
#   bastion_host             = "18.135.45.32"
#   bastion_user             = "ubuntu"
#   bastion_private_key_path = "${path.module}/webkey.pem"
# }
