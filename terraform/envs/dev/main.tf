####################################################################
# dev environment — root module
#
# Wires together the reusable modules:
#   network -> ecr -> database -> compute -> monitoring
####################################################################

module "network" {
  source = "../../modules/network"

  project     = var.project
  environment = var.environment
  vpc_cidr    = var.vpc_cidr
  app_port    = var.app_port
  admin_cidr  = var.admin_cidr
}

module "ecr" {
  source = "../../modules/ecr"

  project     = var.project
  environment = var.environment
}

module "database" {
  source = "../../modules/database"

  project              = var.project
  environment          = var.environment
  private_subnet_ids   = module.network.private_subnet_ids
  db_security_group_id = module.network.db_security_group_id
  instance_class       = var.db_instance_class
  db_name              = var.db_name
  db_username          = var.db_username
}

module "compute" {
  source = "../../modules/compute"

  project               = var.project
  environment           = var.environment
  aws_region            = var.aws_region
  vpc_id                = module.network.vpc_id
  public_subnet_ids     = module.network.public_subnet_ids
  app_security_group_id = module.network.app_security_group_id
  alb_security_group_id = module.network.alb_security_group_id
  instance_type         = var.instance_type
  key_name              = var.key_name
  app_port              = var.app_port
  ecr_repository_url    = module.ecr.repository_url
  image_tag             = var.image_tag
  db_ssm_parameter_name = module.database.ssm_parameter_name
  db_ssm_parameter_arn  = module.database.ssm_parameter_arn

  depends_on = [module.database]
}

module "monitoring" {
  source = "../../modules/monitoring"

  project                = var.project
  environment            = var.environment
  aws_region             = var.aws_region
  alarm_email            = var.alarm_email
  instance_id            = module.compute.instance_id
  alb_arn                = module.compute.alb_arn
  target_group_arn       = module.compute.target_group_arn
  db_instance_identifier = module.database.db_instance_identifier

  depends_on = [module.compute, module.database]
}
