variable "aws_region" {
  description = "AWS Region"
  default     = "ap-south-1"
}

variable "app_name" {
  description = "Application name"
  default     = "cloudnativewebapi"
}

variable "instance_type" {
  default = "t3.medium"
}

variable "key_name" {
  description = "SanthoshJenkinsPipelineKeypair.pem"
  type = string
  default = "SanthoshJenkinsPipelineKeypair"
}