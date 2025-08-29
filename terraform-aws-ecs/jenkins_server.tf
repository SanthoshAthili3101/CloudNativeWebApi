# Fetch default VPC
data "aws_vpc" "default" {
  default = true
}

# Latest Ubuntu 20.04 (Focal) AMD64 from Canonical
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# Security group for Jenkins host
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  description = "Allow SSH and Jenkins HTTP"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # tighten in production
  }

  ingress {
    description = "Jenkins UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # tighten in production
  }

  # Optional: HTTP 80 if hosting anything else locally
  ingress {
    description = "HTTP"
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

# Jenkins EC2 instance with full bootstrap
resource "aws_instance" "jenkins_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.jenkins_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    set -ex
    exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

    echo "=== Base updates ==="
    apt-get update -y
    apt-get upgrade -y
    apt-get install -y curl wget unzip gnupg ca-certificates apt-transport-https software-properties-common

    echo "=== Install Java & Jenkins ==="
    apt-get install -y openjdk-17-jdk

    # Clean old Jenkins repo config if present
    rm -f /usr/share/keyrings/jenkins-keyring.gpg
    rm -f /etc/apt/sources.list.d/jenkins.list

    # Add Jenkins apt repo and install
    curl -fsSL https://pkg.jenkins.io/debian/jenkins.io-2023.key | gpg --dearmor | tee /usr/share/keyrings/jenkins-keyring.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.gpg] https://pkg.jenkins.io/debian binary/" | tee /etc/apt/sources.list.d/jenkins.list
    apt-get update -y
    apt-get install -y jenkins
    systemctl enable jenkins
    systemctl start jenkins

    echo "=== Install Docker Engine ==="
    # Use Ubuntu docker.io for simplicity; switch to Docker repo if desired
    apt-get remove -y docker docker-engine docker.io containerd runc || true
    apt-get install -y docker.io
    systemctl enable docker
    systemctl start docker

    # Allow Jenkins to run docker without sudo
    usermod -aG docker jenkins
    # Restart Jenkins so new group assignment applies
    systemctl restart jenkins || true

    echo "=== Install AWS CLI v2 ==="
    apt-get install -y unzip
    curl -sSLo /tmp/awscliv2.zip "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
    unzip -q /tmp/awscliv2.zip -d /tmp/
    /tmp/aws/install || /tmp/aws/install --update
    rm -rf /tmp/aws /tmp/awscliv2.zip
    aws --version || true

    echo "=== Install Microsoft repo + .NET 8 SDK ==="
    curl -sSLo /tmp/packages-microsoft-prod.deb https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb
    dpkg -i /tmp/packages-microsoft-prod.deb
    rm -f /tmp/packages-microsoft-prod.deb
    apt-get update -y
    apt-get install -y dotnet-sdk-8.0
    dotnet --info || true

    echo "=== Install jq ==="
    apt-get install -y jq

    echo "=== Versions ===" | tee -a /var/log/jenkins-setup.log
    java -version 2>&1 | tee -a /var/log/jenkins-setup.log
    jenkins --version 2>/dev/null | tee -a /var/log/jenkins-setup.log || true
    docker --version | tee -a /var/log/jenkins-setup.log
    aws --version | tee -a /var/log/jenkins-setup.log
    dotnet --info | head -n 25 | tee -a /var/log/jenkins-setup.log
    jq --version | tee -a /var/log/jenkins-setup.log

    echo "=== Jenkins initial admin password ===" | tee -a /var/log/jenkins-setup.log
    cat /var/lib/jenkins/secrets/initialAdminPassword >> /var/log/jenkins-setup.log 2>/dev/null || echo "Not ready; check /var/lib/jenkins/secrets/initialAdminPassword" | tee -a /var/log/jenkins-setup.log

    echo "=== Bootstrap completed ==="
  EOF

  tags = {
    Name = "JenkinsServer"
  }
}
