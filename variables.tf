variable "instance_name" {
  description = "The alue of EC2 instance's name tag"
  type        = string
  default     = "Scotts EC2 Instance of Knowledge"
}

variable "instance_type" {
  description = "The type of EC2 instance we're spinning up"
  type        = string
  default     = "t3.micro"
}

