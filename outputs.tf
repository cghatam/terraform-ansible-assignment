output "web_server_public_ip" {
  description = "Public IP address of the web server EC2 instance"
  value       = aws_instance.web_server.public_ip
}

output "db_server_private_ip" {
  description = "Private IP address of the database EC2 instance"
  value       = aws_instance.db_server.private_ip
}