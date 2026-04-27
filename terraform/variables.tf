variable "availability_zones" {
  type = list(string)
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate used for HTTPS"
  type        = string
}

# variable "db_username" {
#   description = "RDS master username"
#   type        = string
#   default     = "pasadmin"
# }

# variable "db_password" {
#   description = "RDS master password"
#   type        = string
#   sensitive   = true
# }