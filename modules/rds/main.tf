resource "aws_db_instance" "this" {
  identifier        = "dev-db"
  engine            = "mysql"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  username = "admin"
  password = "password123"

  vpc_security_group_ids = [var.security_group_id]
  db_subnet_group_name = aws_db_subnet_group.this.name

  publicly_accessible = false
  skip_final_snapshot = true
}
resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.name}-db-subnet-group"
  }
}
