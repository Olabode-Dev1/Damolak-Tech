variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "damolak-devops-demo"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "key_name" {
  type = string
}

variable "admin_cidr_blocks" {
  type = list(string)
}

variable "subnet_id" {
  type    = string
  default = ""
}

variable "root_volume_size" {
  type    = number
  default = 30
}

variable "jenkins_port" {
  type    = number
  default = 8080
}

variable "terraform_version" {
  type    = string
  default = "1.8.5"
}

variable "extra_policy_arns" {
  type    = list(string)
  default = []
}
