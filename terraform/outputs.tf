output "vpc_id" {
  value = module.networking.vpc_id
}

# output "rds_endpoint" {
#   description = "PostgreSQL RDS endpoint for app configuration"
#   value       = module.rds.endpoint
# }

# output "rds_host" {
#   value = module.rds.host
# }

# output "rds_db_name" {
#   value = module.rds.db_name
# }

# output "rds_schema_applied" {
#   description = "null_resource ID confirming schema was applied — containers can depend on this"
#   value       = module.rds.schema_applied
# }