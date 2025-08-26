# 1. VPC for the application
resource "aws_vpc" "tymbbc_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "tymbbc-vpc"
  }
}

# 2. Public Subnet for the VPC
resource "aws_subnet" "tymbbc_subnet" {
  vpc_id                  = aws_vpc.tymbbc_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "tymbbc-public-subnet"
  }
}

# 3. Internet Gateway for internet access
resource "aws_internet_gateway" "tymbbc_igw" {
  vpc_id = aws_vpc.tymbbc_vpc.id
  tags = {
    Name = "tymbbc-igw"
  }
}

# 4. Route Table for the public subnet
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

# 5. Route Table Association
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.tymbbc_subnet.id
  route_table_id = aws_route_table.tymbbc_rt.id
}

# 6. Security Group for the EC2 Instance
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
    cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]
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

# Get your public IP to restrict SSH access 
data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}
