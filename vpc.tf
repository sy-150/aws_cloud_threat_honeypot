# Patterns:
# resource "<provider>_<resource_type>" "<local reference name>" {
# 1. Mandatory Parameters
# 2. Metadata & Name
# }

# Creating the VPC
# Enabling DNS Support and Hostnames
resource "aws_vpc" "vpc1" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# Creating the Internet Gateway to enable Internet access
# Attached directly to the previously created VPC
resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.vpc1.id
}

# Creating availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Creating 2 public subnets with different IPv4 CIDR Blocks and Availability Zones
# Uses the count parameter to create a list to iterate through, used in the CIDR Block and Availability Zone
# Different Availability Zones to avoid total service shutdown should a single AZ fail.
resource "aws_subnet" "subnets_public" {
  count                   = 2
  vpc_id                  = aws_vpc.vpc1.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}

# Creating private subnets with a similar method to the public subnets
# Does not map public ip as it is private, without interactions with users
# Not used as of now 29/08/2026
resource "aws_subnet" "subnets_private" {
  count             = 2
  vpc_id            = aws_vpc.vpc1.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 3)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "private-subnet-${count.index + 1}"
  }
}

# Creating route table for the public subnet
# Gateway to and from the internet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc1.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id
  }
}

# Associating the public subnets with the route table
# Iterates using count and its indexes
resource "aws_route_table_association" "public_route_table_association" {
  count          = 2
  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = aws_subnet.subnets_public[count.index].id
}