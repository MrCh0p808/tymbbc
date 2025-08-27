# 1. EC2 Instance to host the application
resource "aws_instance" "tymbbc_server" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.tymbbc_subnet.id
  vpc_security_group_ids = [aws_security_group.tymbbc_sg.id]
  key_name      = aws_key_pair.tymbbc_key.key_name
  # User data script to install and run the application
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y python3-pip git
              pip3 install flask flask-socketio gunicorn
              git clone https://github.com/MrCh0p808/tymbbc.git /home/ec2-user/tymbbc_app
              cd /home/ec2-user/tymbbc_app
              nohup gunicorn --bind 0.0.0.0:80 app:app &
              EOF

  tags = {
    Name = "tymbbc-Server"
  }
}

# 2. Output the public IP of the EC2 instance
output "instance_public_ip" {
  value = aws_instance.tymbbc_server.public_ip
}
