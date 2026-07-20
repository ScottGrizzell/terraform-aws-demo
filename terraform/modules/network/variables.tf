variable "aws_region" {
  type        = string
  # Removed default so that it relies on passing in a value from where i call the module
  description = "go duck! (because us-west-2 is in oregon)"
}