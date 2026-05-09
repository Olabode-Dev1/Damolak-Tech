variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "bucket_name" {
  type = string
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "project_name" {
  type    = string
  default = "damolak-devops-demo"
}
