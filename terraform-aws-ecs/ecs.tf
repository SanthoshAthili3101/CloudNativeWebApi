# ECS Task Definition (new) — family name must match what Jenkins uses
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.app_name}-task"        # e.g. cloudnativewebapi-task
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = var.app_name                              # "cloudnativewebapi"
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      essential = true
      portMappings = [
        { containerPort = 8080, protocol = "tcp" }          # app listens on 8080 in container
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

# ECS Service (new) — name must match what Jenkins uses
resource "aws_ecs_service" "app" {
  name            = "${var.app_name}-service"               # e.g. cloudnativewebapi-service
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = ["subnet-06c51c2372e385e6c", "subnet-0801a685101ee8955"]   # TODO: replace with real subnet IDs
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
}



# ECS cluster (already present)
resource "aws_ecs_cluster" "app_cluster" {
  name = "${var.app_name}-cluster"
}
