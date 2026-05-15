terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
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

variable "nlb_arn" {
  type    = string
  default = ""
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

data "aws_lb" "ags" {
  count = var.nlb_arn == "" ? 1 : 0

  tags = {
    GraphServiceId = var.graph_service_id
    Purpose        = "ags-gremlin"
  }
}

locals {
  selected_nlb_arn = var.nlb_arn != "" ? var.nlb_arn : one(data.aws_lb.ags[*].arn)
}

data "aws_lb" "selected" {
  arn = local.selected_nlb_arn
}

resource "aws_vpc_endpoint_service" "ags" {
  acceptance_required        = true
  network_load_balancer_arns = [local.selected_nlb_arn]

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
  value = data.aws_lb.selected.dns_name
}
