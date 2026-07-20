# This is kinda like setting up logs so we can see what stuff is getting set as or doing

output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "The ID of the VPC"
}

output "public_subnet_1_id" {
  value       = module.vpc.public_subnet_1_id
  description = "The ID of public subnet 1 in our AZ-A"
}

output "public_subnet_2_id" {
  value       = module.vpc.public_subnet_2_id
  description = "The ID of public subnet 2 in our AZ-B"
}

output "security_group_id" {
  value       = module.vpc.security_group_id
  description = "The ID of our base cluster security group"
}

output "ecr_repository_url" {
  value       = module.ecr.ecr_repository_url
  description = "The endpoint for logging into docker and pushing images into our rep"
}