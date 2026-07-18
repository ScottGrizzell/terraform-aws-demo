output "instance_hostname" {
  description = "The private DNS name of my EC2 instance"
  value       = aws_instance.app_server.private_dns
}