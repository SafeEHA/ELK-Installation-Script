provider "aws" {
  region = "us-west-2"  # Adjust to your preferred region
}

resource "aws_security_group" "elk_sg" {
  name        = "elk-security-group"
  description = "Security group for ELK stack"

  # Elasticsearch ports
  ingress {
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kibana ports
  ingress {
    from_port   = 5601
    to_port     = 5601
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP port
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS port
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Logstash Beats input port
  ingress {
    from_port   = 5044
    to_port     = 5044
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Replace with your IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "elk_server" {
  ami           = "ami-075686beab831bb7f"  # Ubuntu AMI (adjust for your region)
  instance_type = "t3.large"  

  root_block_device {
    volume_type = "gp3"
    volume_size = 28 
    encrypted   = true
  }

  key_name      = "test-keypair"  # Replace with your EC2 key pair name

  security_groups = [aws_security_group.elk_sg.name]

  tags = {
    Name = "ELK-Server"
  }
}

output "elk_server_public_ip" {
  value = aws_instance.elk_server.public_ip
}
output "elk_server_private_ip" {
  value = aws_instance.elk_server.private_ip

}
