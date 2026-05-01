terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.11"
    }
  }
}

variable "customer" {
  type = string
}

variable "environment" {
  type = string
}

variable "graph_service_id" {
  type = string
}

variable "endpoint_service_allowed_principal" {
  type    = string
  default = ""
}

variable "vpc_id" {
  type = string
}

variable "aws_region" {
  type = string
}

provider "aws" {
  region = var.aws_region
}

locals {
  port        = 8182
  name_prefix = "${var.customer}-${var.environment}"
  common_tags = {
    Customer       = var.customer
    Environment    = var.environment
    GraphServiceId = var.graph_service_id
    Purpose        = "ags-privatelink"
  }
}

resource "time_sleep" "wait_for_load_balancer" {
  create_duration = "90s"
}

data "aws_lb" "ags" {
  tags = {
    GraphServiceId = var.graph_service_id
    Purpose        = "ags-gremlin"
  }

  depends_on = [time_sleep.wait_for_load_balancer]
}

resource "aws_vpc_endpoint_service" "ags" {
  acceptance_required        = true
  network_load_balancer_arns = [data.aws_lb.ags.arn]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ags-privatelink"
  })
}

resource "aws_vpc_endpoint_service_allowed_principal" "customer" {
  count                   = var.endpoint_service_allowed_principal == "" ? 0 : 1
  vpc_endpoint_service_id = aws_vpc_endpoint_service.ags.id
  principal_arn           = var.endpoint_service_allowed_principal
}

output "privatelink_service_name" {
  value = aws_vpc_endpoint_service.ags.service_name
}

output "privatelink_service_id" {
  value = aws_vpc_endpoint_service.ags.id
}

output "privatelink_port" {
  value = local.port
}

output "privatelink_acceptance_required" {
  value = aws_vpc_endpoint_service.ags.acceptance_required
}

output "privatelink_allowed_principal" {
  value = var.endpoint_service_allowed_principal
}

output "privatelink_nlb_dns_name" {
  value = data.aws_lb.ags.dns_name
}
