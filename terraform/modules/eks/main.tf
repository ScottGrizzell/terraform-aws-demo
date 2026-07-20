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
    security_group_ids = var.vpc_sgs
    # telling the control plane feel free to put stuff in both our subnets we set up
    subnet_ids = var.subnet_ids
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
  subnet_ids      = var.subnet_ids

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