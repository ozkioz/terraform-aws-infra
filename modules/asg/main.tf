resource "aws_launch_template" "this" {
  name_prefix   = "${var.name}-lt"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"

  vpc_security_group_ids = [var.security_group_id]

  iam_instance_profile {
    name = var.instance_profile_name
  }

  user_data = base64encode(<<EOF
#!/bin/bash
yum install -y httpd
systemctl start httpd
echo "Hello from $(hostname)" > /var/www/html/index.html
EOF
  )
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_autoscaling_group" "this" {
  desired_capacity = 2
  max_size         = 3
  min_size         = 2

  vpc_zone_identifier = var.subnet_ids

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  target_group_arns = [var.target_group_arn]
}
