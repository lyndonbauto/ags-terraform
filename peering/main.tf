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

variable "peering_id" {
  type = string
}

variable "hosted_zone_id" {
  type = string
}

variable "peer_vpc_cidr" {
  type = string
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
  name_prefix = "${var.customer}-${var.environment}"
  common_tags = {
    Customer    = var.customer
    Environment = var.environment
  }
}

data "aws_route_tables" "all" {
  vpc_id = var.vpc_id
}

resource "aws_vpc_peering_connection_accepter" "this" {
  vpc_peering_connection_id = var.peering_id
  auto_accept               = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-peering-accepter"
    Side = "Accepter"
  })
}

resource "aws_route" "peer" {
  for_each                  = toset(data.aws_route_tables.all.ids)
  route_table_id            = each.value
  destination_cidr_block    = var.peer_vpc_cidr
  vpc_peering_connection_id = var.peering_id

  depends_on = [aws_vpc_peering_connection_accepter.this]
}

resource "aws_route53_zone_association" "peer" {
  zone_id = var.hosted_zone_id
  vpc_id  = var.vpc_id

  lifecycle {
    ignore_changes = [vpc_id]
  }
}

output "peering_status" {
  value = aws_vpc_peering_connection_accepter.this.accept_status
}

output "peering_route_table_ids" {
  value = data.aws_route_tables.all.ids
}
