# defining our virtual private cloud to have an isolated network
resource "aws_vpc" "eks_vpc" {
  # Classless inter-domain routing this is saying of the 2^32 possible addresses
  # -- we get to use 2^(32-16) of them in our network
  cidr_block = "10.0.0.0/16"

  # this is saying allow us to map a human readable DNS names to our IPs 
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Like labels in the k8s world. a query string we can use to find our VPC resources
  tags = {
    Name = "k8s-training-vpc"
  }
}