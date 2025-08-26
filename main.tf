# 1. AWS Provider Configuration
provider "aws" {
  region = "us-east-1"
}

# 2. Data source for the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# 3. Linking local public SSH key to AWS
resource "aws_key_pair" "tymbbc_key" {
  key_name   = "tymbbc-server-key"
  public_key = file("~/.ssh/tf-aws-key.pub")
}
