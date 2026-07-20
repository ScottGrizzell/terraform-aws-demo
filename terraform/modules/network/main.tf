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

# Adding an Internet gateway this is like building a door to the internet for our VPC so people
# -- can actually access our public subnets
resource "aws_internet_gateway" "eks_igw" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = {
    Name = "k8s-training-igw"
  }
}

# This table acts like a highway exit sign for traffic leaving our network. kinda a mid analogy
# It doesn't manage people walking in; it tells packets inside our subnet how to get OUT.
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.eks_vpc.id

  # Destination rules for any traffic leaving resources associated with this table
  route {
    # 0.0.0.0/0 means "The entire Internet" (any address not inside our VPC).
    # This rule says: "If a packet is headed outside our private network, send it 
    # out through our Internet Gateway so it can reach the global web."
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_igw.id
  }
  tags = {
    Name = "k8s-public-route-table"
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}


# Creating security group rules to manage what taffic is allowed to go in and out
# This is a stateful chuck unlike a NACL (network access control list)
resource "aws_security_group" "eks_cluster_sg" {
  name        = "k8s-training-cluster-sg"
  description = "Base firewall rules for training cluster"
  vpc_id      = aws_vpc.eks_vpc.id # links these rules to our VPC

  # Inbound rules: These say what is allowed to enter our VPC/subnets
  # This rule is saying allow any web traffic on port 80
  ingress {
    description = " Allow http web traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # allow traffic from anywhere
  }
   ingress {
    description = " Allow https web traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # allow traffic from anywhere
  }


  #This rule is saying allow shell SSHing on port 22
  ingress {
    description = "Allow SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # allow traffic from anywhere
  }

  # Outbound rules: These say what is allowed to leave our VPC/subnets
  egress {
    # setting from and to port 0 when protocol is -1 means allow all traffic to leave the VPC
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"] # allow traffic to anywhere
  }

  tags = {
    Name = "k8s-cluster-security-group"
  }
}

resource "aws_security_group_rule" "nodeport_range" {
  type              = "ingress"
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_cluster_sg.id
  description       = "Allow LoadBalancer traffic to reach NodePort services"
}