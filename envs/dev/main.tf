module "ec2" {
  source        = "../../modules/ec2"
  aws_region    = "us-east-1"
  instance_type = "t2.micro"
  name          = "dev-ec2"
}
