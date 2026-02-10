terraform {
  backend "s3" {
    bucket         = "terraform-state-oskar-123"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
module "ec2" {
  source        = "../../modules/ec2"
  aws_region    = "us-east-1"
  instance_type = "t2.micro"
  name          = "dev-ec2"
}
