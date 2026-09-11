output "db_instance_id" {
  value = aws_db_instance.main.id
}

output "db_instance_arn" {
  value = aws_db_instance.main.arn
}

output "db_endpoint" {
  value     = aws_db_instance.main.endpoint
  sensitive = true
}

output "db_address" {
  value     = aws_db_instance.main.address
  sensitive = true
}

output "db_port" {
  value = aws_db_instance.main.port
}

output "security_group_id" {
  value = aws_security_group.rds.id
}

output "credentials_secret_arn" {
  value = aws_secretsmanager_secret.db_credentials.arn
}

output "subnet_group_name" {
  value = aws_db_subnet_group.main.name
}
