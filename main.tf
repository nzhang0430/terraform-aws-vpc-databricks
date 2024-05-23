provider "databricks" {
  host  = "https://<databricks-instance>"
  token = "<databricks-token>"
}

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
