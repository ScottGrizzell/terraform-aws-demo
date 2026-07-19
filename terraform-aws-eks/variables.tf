variable "aws_region" {
  type        = string
  default     = "us-west-2"
  description = "go duck! (because us-west-2 is in oregon)"
}

variable "grafana_admin_password" {
  type        = string
  sensitive   = true
}