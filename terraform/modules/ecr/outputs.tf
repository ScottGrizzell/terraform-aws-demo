output "ecr_repository_url" {
  value       = aws_ecr_repository.web_app_repo.repository_url
  description = "The endpoint for logging into docker and pushing images into our rep"
}