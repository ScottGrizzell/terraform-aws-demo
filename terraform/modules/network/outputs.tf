output "vpc_id" {
  value       = aws_vpc.eks_vpc.id
  description = "The ID of the VPC"
}

output "public_subnet_ids" {
  value = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  description = "The IDs of the public subnets. This output waits for route table associations to finish."
  
  depends_on = [
    aws_route_table_association.public_1_assoc,
    aws_route_table_association.public_2_assoc
  ]
}

output "security_group_id" {
  value       = aws_security_group.eks_cluster_sg.id
  description = "The ID of our base cluster security group"
}

