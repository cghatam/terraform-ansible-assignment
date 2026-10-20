variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "my_ip" {
  type        = string
  description = "Public IP address in CIDR notation (e.g., 203.0.113.50/32) for secure SSH access"
}

variable "key_name" {
  type        = string
  description = "Name of your existing AWS EC2 Key Pair"
}

variable "ami_id" {
  type        = string
  description = "Ubuntu 24.04 LTS AMI ID for your region"
  default     = "ami-0b6d9d3d33ba97d99" # Update as per your region if needed
}