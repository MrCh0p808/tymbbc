# Get your public IP to restrict SSH access (optional but recommended)
data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

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

# 3. VPC for the application
resource "aws_vpc" "tymbbc_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "tymbbc-vpc"
  }
}

# 4. Public Subnet for the VPC
resource "aws_subnet" "tymbbc_subnet" {
  vpc_id                  = aws_vpc.tymbbc_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "tymbbc-public-subnet"
  }
}

# 5. Internet Gateway for internet access
resource "aws_internet_gateway" "tymbbc_igw" {
  vpc_id = aws_vpc.tymbbc_vpc.id
  tags = {
    Name = "tymbbc-igw"
  }
}

# 6. Route Table for the public subnet
resource "aws_route_table" "tymbbc_rt" {
  vpc_id = aws_vpc.tymbbc_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tymbbc_igw.id
  }

  tags = {
    Name = "tymbbc-public-route-table"
  }
}

# 7. Route Table Association
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.tymbbc_subnet.id
  route_table_id = aws_route_table.tymbbc_rt.id
}

# 8. Security Group for the EC2 Instance
resource "aws_security_group" "tymbbc_sg" {
  name        = "tymbbc-sg"
  description = "Allow HTTP and SSH inbound traffic"
  vpc_id      = aws_vpc.tymbbc_vpc.id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]  
}

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tymbbc-sg"
  }
}

# 9. EC2 Instance to host the application
resource "aws_instance" "tymbbc_server" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.tymbbc_subnet.id
  vpc_security_group_ids = [aws_security_group.tymbbc_sg.id]

  # User data script to install and run the application
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y python3-pip git
              pip3 install flask flask-socketio gunicorn
              git clone https://github.com/MrCh0p808/tymbbc.git /home/ec2-user/tymbbc_app # Replace with your repo URL
              cd /home/ec2-user/tym_bbc
              gunicorn --bind 0.0.0.0:80 app:app
              EOF

  tags = {
    Name = "tymbbc-Server"
  }
}

# 10. Output the public IP of the EC2 instance
output "instance_public_ip" {
  value = aws_instance.tymbbc_server.public_ip
}
