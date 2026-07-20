output "vpc_id" {
  value       = aws_vpc.eks_vpc.id
  description = "The ID of the VPC"
}

output "public_subnet_1_id" {
  value       = aws_subnet.public_1.id
  description = "The ID of public subnet 1 in our AZ-A"
}

output "public_subnet_2_id" {
  value       = aws_subnet.public_2.id
  description = "The ID of public subnet 2 in our AZ-B"
}

output "security_group_id" {
  value       = aws_security_group.eks_cluster_sg.id
  description = "The ID of our base cluster security group"
}