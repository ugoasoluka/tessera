data "aws_region" "current" {}

resource "aws_vpc" "vpc" {
  cidr_block           = var.settings["main"]["cidr"]
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { "Name" = var.settings["main"]["name"] })
}

resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.vpc.id
  tags   = merge(var.tags, { "Name" = var.settings["main"]["name"] })
}

# Public subnets

resource "aws_subnet" "public" {
  for_each                = toset(var.availability_zones)
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.settings[each.key]["cidr_public"]
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = merge(var.tags, { "Name" = "${var.settings["main"]["name"]}-${each.key}-public" })
}

resource "aws_route_table" "public" {
  for_each = toset(var.availability_zones)
  vpc_id   = aws_vpc.vpc.id

  tags = merge(var.tags, { "Name" = "${var.settings["main"]["name"]}-${each.key}-public" })
}

resource "aws_route_table_association" "public" {
  for_each       = toset(var.availability_zones)
  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public[each.key].id
}

resource "aws_route" "igw" {
  for_each               = toset(var.availability_zones)
  route_table_id         = aws_route_table.public[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.default.id
}


# NAT Gateways


resource "aws_eip" "nat_gw" {
  for_each = toset(var.availability_zones)
  domain   = "vpc"

  tags = merge(var.tags, { "Name" = "${var.settings["main"]["name"]}-${each.key}-nat" })
}

resource "aws_nat_gateway" "nat_gw" {
  for_each      = toset(var.availability_zones)
  allocation_id = aws_eip.nat_gw[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge(var.tags, { "Name" = "${var.settings["main"]["name"]}-${each.key}-nat" })
}


# Private subnets


resource "aws_subnet" "private" {
  for_each          = toset(var.availability_zones)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.settings[each.key]["cidr_private"]
  availability_zone = each.key

  tags = merge(var.tags, { "Name" = "${var.settings["main"]["name"]}-${each.key}-private" })
}

resource "aws_route_table" "private" {
  for_each = toset(var.availability_zones)
  vpc_id   = aws_vpc.vpc.id

  tags = merge(var.tags, { "Name" = "${var.settings["main"]["name"]}-${each.key}-private" })
}

resource "aws_route_table_association" "private" {
  for_each       = toset(var.availability_zones)
  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}

resource "aws_route" "nat_gw" {
  for_each               = toset(var.availability_zones)
  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw[each.key].id
}


# Data subnets


resource "aws_subnet" "data" {
  for_each          = toset(var.availability_zones)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.settings[each.key]["cidr_data"]
  availability_zone = each.key

  tags = merge(var.tags, { "Name" = "${var.settings["main"]["name"]}-${each.key}-data" })
}

resource "aws_route_table" "data" {
  for_each = toset(var.availability_zones)
  vpc_id   = aws_vpc.vpc.id

  tags = merge(var.tags, { "Name" = "${var.settings["main"]["name"]}-${each.key}-data" })
}

resource "aws_route_table_association" "data" {
  for_each       = toset(var.availability_zones)
  subnet_id      = aws_subnet.data[each.key].id
  route_table_id = aws_route_table.data[each.key].id
}