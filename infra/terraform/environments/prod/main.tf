data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "network" {
  source = "../../modules/network"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = local.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = var.environment
}

locals {
  container_repository = var.image_repository_override != "" ? var.image_repository_override : module.ecr.repository_url
  container_image      = "${local.container_repository}:${var.image_tag}"
}

module "ecs_service" {
  source = "../../modules/ecs_service"

  project_name       = var.project_name
  environment        = var.environment
  aws_region         = var.aws_region
  vpc_id             = module.network.vpc_id
  public_subnet_ids  = module.network.public_subnet_ids
  private_subnet_ids = module.network.private_subnet_ids
  container_image    = local.container_image
  container_port     = var.container_port
  desired_count      = var.desired_count
  cpu                = var.cpu
  memory             = var.memory
}

