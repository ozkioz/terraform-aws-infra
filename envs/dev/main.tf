provider "aws" {
  region = var.aws_region
}
terraform {
  backend "s3" {
    bucket         = "kunda-terraform-state-bucket-12345"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
module "rds" {
  source = "../../modules/rds"

  name              = "dev"
  security_group_id = module.vpc.rds_security_group_id
  subnet_ids = module.vpc.private_subnet_ids
}
module "iam" {
  source       = "../../modules/iam"
  project_name = "dev"
}
module "vpc" {
  source = "../../modules/vpc"
 name              = "dev"
  aws_region = var.aws_region
  vpc_cidr   = var.vpc_cidr
  vpc_name   = var.vpc_name
}
module "alb" {
  source = "../../modules/alb"

  name              = "dev"
  vpc_id            = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnet_ids
  security_group_id = module.vpc.alb_sg_id
}
module "asg" {
  source = "../../modules/asg"

  name                  = "dev"
  security_group_id     = module.vpc.ec2_security_group_id
  instance_profile_name = module.iam.instance_profile_name
  subnet_ids = module.vpc.private_subnet_ids
  target_group_arn      = module.alb.target_group_arn
}
