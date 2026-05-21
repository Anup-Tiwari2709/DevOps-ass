variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "owner_cidr" {
  type        = string
  description = "CIDR range for SSH access to the API gateway instance"
  default     = "0.0.0.0/0"
}

variable "public_key_path" {
  type        = string
  description = "Path to the SSH public key used for EC2 access"
  default     = ""
}
