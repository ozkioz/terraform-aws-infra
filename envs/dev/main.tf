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
module "ec2" {
  source = "../../modules/ec2"

  name                  = "dev-ec2"
  aws_region            = var.aws_region
  instance_profile_name = module.iam.instance_profile_name
  security_group_id = module.vpc.ec2_sg_id
  subnet_id = module.vpc.public_subnet_id
}
module "rds" {
  source = "../../modules/rds"
  security_group_id = module.vpc.ec2_sg_id
}
module "iam" {
  source       = "../../modules/iam"
  project_name = "dev"
}
module "vpc" {
  source = "../../modules/vpc"

  aws_region = var.aws_region
  vpc_cidr   = "10.0.0.0/16"
  name       = "dev"
}