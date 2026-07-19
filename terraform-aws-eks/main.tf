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

# Associate our public subnet with the route table we setup
resource "aws_route_table_association" "public_1_assoc" {
  # Subnet we're associating our table with
  subnet_id = aws_subnet.public_1.id
  # route table we're associating to our subnet
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_2_assoc" {
  # Subnet we're associating our table with
  subnet_id = aws_subnet.public_2.id
  # route table we're associating to our subnet
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


# Setting up IAM (Identiy & Access Management) roles for our EKS cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "k8s-training-cluster-role"

  # This is defining our role and who is allowed to have it
  # Defining who is allowed to have a role is called a trust policy
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        # This says the only person who can have this role is eks
        Service = "eks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "k8s-cluster-iam-role"
  }
}
# This is the permission policy, it gets attached to a role and state the permissions
# -- and access that role will be able to have
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role = aws_iam_role.eks_cluster_role.name
  # This is a prebaked set of rules that amazon has defined and we are attaching to our eks_cluster_role
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy" #arn - amazon resource name
  # This policy specifically gives the k8s control plane permission to manage resources and things inside its cluster
}

# Creating Identity & Access Management role for our worker nodes
resource "aws_iam_role" "eks_node_role" {
  name = "k8s-training-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
  tags = {
    Name = "k8s-node-iam-role"
  }
}
# We are making three different Permission Policies for our nodes to attach to our role
resource "aws_iam_role_policy_attachment" "amazon_eks_worker_node_policy" {
  # Gives access to nodes to interact with the master cluster control plane
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "amazon_eks_cni_policy" {
  # Gives permissions for nodes to be able to get private Ips in the VPC
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
resource "aws_iam_role_policy_attachment" "amazon_ec2_container_registry_read_only" {
  # Gives the nodes permission to pull docker imagess from ECR (Elastic Container Registry)
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Now we're setting up a private docker registry with ECR to hold our docker images
resource "aws_ecr_repository" "web_app_repo" {
  name                 = "static-web-app"
  image_tag_mutability = "MUTABLE" # this lets us overwrite tags when pushing a tag with the same name

  # Automatically scan images we push to the repo for vulnerabilities 
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "k8s-training-ecr"
  }
}

# Creating the K8s control plane in EKS!!!
resource "aws_eks_cluster" "training_cluster" {
  name = "k8s-training-cluster"
  # This is the cluster role we set up earlier!!!
  role_arn = aws_iam_role.eks_cluster_role.arn

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }
  vpc_config {
    # Connecting to our firewall sg we setup earlier
    security_group_ids = [aws_security_group.eks_cluster_sg.id]
    # telling the control plane feel free to put stuff in both our subnets we set up
    subnet_ids = [
      aws_subnet.public_1.id,
      aws_subnet.public_2.id
    ]
  }

  # Explicitly saying what until the role's permission policy has been configured before we build the resource
  # If we built the cluster before the policy it wouldn't be authorized to do anything
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

# Creating the pool of worker nodes to deploy pods too
resource "aws_eks_node_group" "training_nodes" {
  cluster_name    = aws_eks_cluster.training_cluster.name
  node_group_name = "k8s-training-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  instance_types = ["t3.small"]

  scaling_config {
    desired_size = 2 # are goal is to have 2 nodes running always
    max_size     = 3
    min_size     = 1
  }

  # make sure the node policy is setup before making the nodes
  depends_on = [
    aws_iam_role_policy_attachment.amazon_eks_worker_node_policy,
    aws_iam_role_policy_attachment.amazon_eks_cni_policy,
    aws_iam_role_policy_attachment.amazon_ec2_container_registry_read_only,
  ]
}

resource "aws_eks_access_entry" "local_admin_access" {
    cluster_name = aws_eks_cluster.training_cluster.name
   principal_arn = "arn:aws:iam::598892456428:user/scott-cli-admin"
    type = "STANDARD"
}

resource "aws_eks_access_policy_association" "local_admin_policy" {
  cluster_name  = aws_eks_cluster.training_cluster.name
  principal_arn = aws_eks_access_entry.local_admin_access.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
  
}



# GITHUB OIDC RESOURCES ------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

resource "aws_iam_role" "github_actions" {
  name = "github-actions-deploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # Restrict to your specific repo - replace with your actual github username/repo
          "token.actions.githubusercontent.com:sub" = "repo:ScottGrizzell/terraform-aws-demo:*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}


# HELM SETUP ---------------------------------------------------------
# Setting up our helm resource with everything it needs to be able to talk to and be aware of our EKS cluster
# Basically like giving it hte Kube Config file locally
provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.training_cluster.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.training_cluster.certificate_authority[0].data)
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.training_cluster.name]
      command     = "aws"
    }
  }
}



resource "helm_release" "monitoring_stack" {
  name             = "monitoring-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true

  set {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }

  depends_on = [
    aws_eks_cluster.training_cluster, 
    aws_eks_node_group.training_nodes,
    aws_eks_access_policy_association.local_admin_policy]
}