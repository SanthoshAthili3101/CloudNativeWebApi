# Fetch default VPC details
data "aws_vpc" "default" {
  default = true
}

# Fetch the latest Ubuntu 20.04 AMI from Canonical
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# Security group for Jenkins EC2 instance
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  description = "Allow SSH and HTTP to Jenkins"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict to your IP in production, e.g., ["203.0.113.0/32"]
  }

  ingress {
    description = "Jenkins HTTP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict to your IP in production
  }

  ingress {
    description = "CloudNativeWebApi HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict to your IP in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 instance for Jenkins server
resource "aws_instance" "jenkins_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.jenkins_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    set -ex  # Exit on error, echo commands
    exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1  # Log output

    echo "Starting Jenkins installation..."

    # Update system
    apt-get update -y
    apt-get upgrade -y

    # Install OpenJDK 17
    apt-get install -y openjdk-17-jdk

    # Remove any existing Jenkins repository configuration
    rm -f /usr/share/keyrings/jenkins-keyring.gpg
    rm -f /etc/apt/sources.list.d/jenkins.list

    # Add Jenkins repository key
    curl -fsSL https://pkg.jenkins.io/debian/jenkins.io-2023.key | gpg --dearmor | tee /usr/share/keyrings/jenkins-keyring.gpg > /dev/null

    # Configure Jenkins repository
    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.gpg] https://pkg.jenkins.io/debian binary/" | tee /etc/apt/sources.list.d/jenkins.list

    # Update and install Jenkins
    apt-get update -y
    apt-get install -y jenkins

    # Enable and start Jenkins
    systemctl enable jenkins
    systemctl start jenkins

    # Log initial admin password
    echo "Jenkins initial admin password:" >> /var/log/jenkins-setup.log
    cat /var/lib/jenkins/secrets/initialAdminPassword >> /var/log/jenkins-setup.log 2>/dev/null || echo "Failed to retrieve initial admin password"
    echo "Jenkins installation completed"
  EOF

  tags = {
    Name = "JenkinsServer"
  }
}