provider "aws" {
  region = "us-west-2"
}

# GITHUB OIDC SETUP
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

resource "aws_iam_role" "github_actions" {
  name = "github-actions-terraform-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${aws_iam_openid_connect_provider.github.arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:ScottGrizzell/terraform-aws-demo:*"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "github_admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "Copy this ARN value into your GitHub Repository Secrets!"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.19.0"

  name = "example-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24"]

  map_public_ip_on_launch = true

  enable_dns_hostnames = true
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical

}

resource "aws_instance" "app_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  vpc_security_group_ids      = [aws_security_group.web_traffic.id]
  subnet_id                   = module.vpc.public_subnets[0]
  user_data_replace_on_change = true
  user_data                   = <<SCRIPT
#!/bin/bash

sleep 15

sudo apt-get update -y
sudo apt-get install nginx -y
sudo systemctl start nginx
sudo systemctl enable nginx

sudo rm -f /var/www/html/index.nginx-debian.html
sudo rm -f /var/www/html/50x.html

sudo cat << 'HTML' > /var/www/html/index.html
${file("index.html")}
HTML

sudo systemctl restart nginx
SCRIPT

  tags = {
    Name = var.instance_name
  }
}

resource "aws_security_group" "web_traffic" {
  name   = "allow-web"
  vpc_id = module.vpc.vpc_id

  # Setting rule to allow all incoming traffic to ec2 instace
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Setting rule to allow all outbound traffic from ec2 instance
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Adding an innagural s3 bucket for storing out .tfstate file for future pipeling configurations
resource "aws_s3_bucket" "terraform_state" {
  bucket        = "scott-grizzell-tf-state-bucket-2026"
  force_destroy = true
}

# Enabling versioning on my bucket so I can have a change historty
resource "aws_s3_bucket_versioning" "tfstate_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

#Encrypting my bucket so that I don't leak info everywhere
resource "aws_s3_bucket_server_side_encryption_configuration" "state_encryption" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Now we make a dynamo db table to access the bucket with to prevent race conditions
resource "aws_dynamodb_table" "terraform_locks" {
  name = "terraform-state-lock-table"
  #This scares me even though requests are billed at the million scale
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}