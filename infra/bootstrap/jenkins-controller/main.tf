data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["137112412989"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

locals {
  name_prefix     = "${var.project_name}-${var.environment}"
  selected_subnet = var.subnet_id != "" ? var.subnet_id : data.aws_subnets.default.ids[0]
  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    jenkins_port      = var.jenkins_port
    terraform_version = var.terraform_version
  })
}

resource "aws_security_group" "jenkins" {
  name        = "${local.name_prefix}-jenkins-sg"
  description = "Access for Jenkins controller"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  ingress {
    from_port   = var.jenkins_port
    to_port     = var.jenkins_port
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.name_prefix}-jenkins-sg"
    Environment = var.environment
  }
}

resource "aws_iam_role" "jenkins" {
  name = "${local.name_prefix}-jenkins-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "extra" {
  for_each = toset(var.extra_policy_arns)

  role       = aws_iam_role.jenkins.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "${local.name_prefix}-jenkins-profile"
  role = aws_iam_role.jenkins.name
}

resource "aws_instance" "jenkins" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  iam_instance_profile        = aws_iam_instance_profile.jenkins.name
  key_name                    = var.key_name
  subnet_id                   = local.selected_subnet
  associate_public_ip_address = true
  vpc_security_group_ids = [
    aws_security_group.jenkins.id
  ]
  user_data = local.user_data

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name        = "${local.name_prefix}-jenkins-controller"
    Environment = var.environment
  }
}
