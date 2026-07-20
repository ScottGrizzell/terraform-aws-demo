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
