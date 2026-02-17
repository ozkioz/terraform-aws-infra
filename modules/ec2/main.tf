data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*"]
  }
}

resource "aws_instance" "this" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "t2.micro"

  subnet_id = var.subnet_id

  iam_instance_profile = var.instance_profile_name

  vpc_security_group_ids = [var.security_group_id]

  tags = {
    Name = var.name
  }
}
