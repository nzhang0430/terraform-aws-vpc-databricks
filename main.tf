provider "aws" {
  region = "us-east-1"
}

provider "databricks" {
  host  = var.databricks_instance
  token = var.databricks_token
}

# VPC and Subnets
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "public_subnet_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_subnet_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public.id
}

# Security Groups
resource "aws_security_group" "web_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Web Servers
resource "aws_launch_configuration" "web_server_lc" {
  name          = "web-server-lc"
  image_id      = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.web_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              EOF
}

resource "aws_autoscaling_group" "web_server_asg" {
  launch_configuration = aws_launch_configuration.web_server_lc.id
  min_size             = 2
  max_size             = 10
  desired_capacity     = 2
  vpc_zone_identifier  = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  tag {
    key                 = "Name"
    value               = "web-server"
    propagate_at_launch = true
  }
}

# Load Balancer
resource "aws_lb" "web_server_alb" {
  name               = "web-server-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
}

resource "aws_lb_target_group" "web_server_tg" {
  name     = "web-server-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_listener" "web_server_listener" {
  load_balancer_arn = aws_lb.web_server_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_server_tg.arn
  }
}

resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.web_server_asg.id
  lb_target_group_arn    = aws_lb_target_group.web_server_tg.arn
}

# PostgreSQL Database
resource "aws_db_instance" "postgres" {
  allocated_storage    = 20
  engine               = "postgres"
  instance_class       = "db.t2.micro"
  name                 = "mydatabase"
  username             = "admin"
  password             = "password"
  parameter_group_name = "default.postgres10"
  db_subnet_group_name = aws_db_subnet_group.postgres_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
}

resource "aws_db_subnet_group" "postgres_subnet_group" {
  name       = "postgres-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]

  tags = {
    Name = "Postgres subnet group"
  }
}

# Databricks
resource "databricks_mws_workspaces" "this" {
  provider           = databricks.mws
  account_id         = var.account_id
  workspace_name     = "my-databricks-workspace"
  deployment_name    = "my-deployment"
  aws_region         = "us-east-1"
  credentials_id     = databricks_mws_credentials.this.credentials_id
  storage_configuration_id = databricks_mws_storage_configurations.this.storage_configuration_id
  managed_services_vpc_endpoint_id = aws_vpc_endpoint.managed_services.id
  vpc_id             = aws_vpc.main.id
  public_subnet_ids  = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  private_subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
}

resource "databricks_mws_credentials" "this" {
  provider          = databricks.mws
  account_id        = var.account_id
  credentials_name  = "my-databricks-credentials"
  role_arn          = aws_iam_role.databricks_role.arn
}

resource "databricks_mws_storage_configurations" "this" {
  provider          = databricks.mws
  account_id        = var.account_id
  storage_configuration_name = "my-databricks-storage"
  bucket_name       = aws_s3_bucket.databricks_bucket.bucket
}

resource "aws_iam_role" "databricks_role" {
  name = "databricks-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "databricks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy_attachment" "databricks_policy_attachment" {
  name       = "databricks-policy-attachment"
  roles      = [aws_iam_role.databricks_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_vpc_endpoint" "managed_services" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  security_group_ids = [aws_security_group.db_sg.id]
}

resource "aws_s3_bucket" "databricks_bucket" {
  bucket = "my-databricks-bucket"

  tags = {
    Name = "databricks-bucket"
  }
}
