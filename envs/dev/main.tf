module "vpc" {
  source     = "../../modules/vpc"
  aws_region = "us-east-1"
  vpc_cidr   = "10.0.0.0/16"
  vpc_name   = "dev-vpc"
}
