variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository in format 'owner/repo' (e.g., 'myorg/my-repo')"
  type        = string
}

variable "image_retention_count" {
  description = "Number of images to retain in ECR repository"
  type        = number
  default     = 10
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

