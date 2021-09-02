# Input variable definitions

variable "aws_region" {
  description = "AWS region for all resources."

  type    = string
  default = "eu-west-1"
}

variable "project" {
  description = "project name"

  type    = string
  default = "gitlab-demo"
}

resource "random_pet" "random" {
  length = 1
}

locals {
  prefix = "${var.project}-${random_pet.random.id}"
}
