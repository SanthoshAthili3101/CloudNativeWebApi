

# Create ECR Repository for Docker Images
resource "aws_ecr_repository" "app" {
  name = var.app_name
}

# Create ECS Cluster
resource "aws_ecs_cluster" "app_cluster" {
  name = "${var.app_name}-cluster"
}

# IAM Role for ECS Tasks Execution
resource "aws_iam_role" "ecs_task_execution" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      },
      Effect = "Allow"
    }]
  })
}

# Attach AmazonECSTaskExecutionRolePolicy to the Role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Security Group allowing inbound HTTP traffic on port 80
resource "aws_security_group" "ecs_sg" {
  name        = "${var.app_name}-sg"
  description = "Allow inbound HTTP traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
