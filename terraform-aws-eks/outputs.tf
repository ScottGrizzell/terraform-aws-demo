# This is kinda like setting up logs so we can see what stuff is getting set as or doing

output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "The ID of the VPC"
}


output "security_group_id" {
  value       = module.vpc.security_group_id
  description = "The ID of our base cluster security group"
}

output "ecr_repository_url" {
  value       = module.ecr.ecr_repository_url
  description = "The endpoint for logging into docker and pushing images into our rep"
}