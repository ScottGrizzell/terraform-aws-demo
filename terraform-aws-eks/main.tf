module "vpc" {
  source = "../terraform/modules/network"
  aws_region = var.aws_region
}

module "eks" {
  source = "../terraform/modules/eks"
  
  vpc_sgs = [module.vpc.security_group_id]
  subnet_ids =  module.vpc.public_subnet_ids
}

module "ecr" {
  source = "../terraform/modules/ecr"
}

module "GithubOIDC" {
  source = "../terraform/modules/GithubOIDC"
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
      command     = "aws"
    }
  }
}

module "monitoring" {
  
  source = "../terraform/modules/monitoring"
  grafana_admin_password = var.grafana_admin_password
  depends_on = [module.eks]
}





