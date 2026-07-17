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

# now we are going to carve our 2^16 ip address we requested into seperate logical subnets
resource "aws_subnet" "public_1" {
  #instead of hard coding anything we can reference the ID of the VPC we just made to set our subnet up on
  # this also tells terraform that this subnet is a dependency of the VPC and will be created after
  # -- the VPC is created
  vpc_id = aws_vpc.eks_vpc.id

  # of the 2^16 address we have on our VPC we are going to carve out 2^(32-24) of them for this
  # -- public subnet
  cidr_block = "10.0.1.0/24"
  #setting our AZ to what we defined in our variables
  availability_zone = "${var.aws_region}a"
  # when we start this subnet map the ips to be public
  map_public_ip_on_launch = true

  tags = {
    Name = "k8s-public-${var.aws_region}a"
  }
}

# make a second public subnet in a different AZ for high avaliablity
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "k8s-public-${var.aws_region}b"
  }
}