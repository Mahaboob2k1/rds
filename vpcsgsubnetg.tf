# Define the AWS provider with your region
provider "aws" {
  region = "ap-south-1"  # Replace with your desired region
}

# Define the VPC
resource "aws_vpc" "PubPrivateVPC" {
  cidr_block = "10.50.0.0/16"

  # Attach internet gateway to VPC
  tags = {
    Name = "PubPrivateVPC"
  }
}

# Define public subnets
resource "aws_subnet" "PublicSubnet1" {
  vpc_id            = aws_vpc.PubPrivateVPC.id
  cidr_block        = "10.50.1.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "PublicSubnet2" {
  vpc_id            = aws_vpc.PubPrivateVPC.id
  cidr_block        = "10.50.2.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "PublicSubnet3" {
  vpc_id            = aws_vpc.PubPrivateVPC.id
  cidr_block        = "10.50.3.0/24"
  availability_zone = "ap-south-1c"
  map_public_ip_on_launch = true
}

# Define private subnets
resource "aws_subnet" "PrivateSubnet1" {
  vpc_id            = aws_vpc.PubPrivateVPC.id
  cidr_block        = "10.50.4.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = false
}

resource "aws_subnet" "PrivateSubnet2" {
  vpc_id            = aws_vpc.PubPrivateVPC.id
  cidr_block        = "10.50.5.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = false
}

resource "aws_subnet" "PrivateSubnet3" {
  vpc_id            = aws_vpc.PubPrivateVPC.id
  cidr_block        = "10.50.6.0/24"
  availability_zone = "ap-south-1c"
  map_public_ip_on_launch = false
}

# Create internet gateway
resource "aws_internet_gateway" "InternetGateway" {
  vpc_id = aws_vpc.PubPrivateVPC.id

  tags = {
    Name = "PubPrivateIGW"
  }
}

# Define public route table and routes
resource "aws_route_table" "PublicRouteTable" {
  vpc_id = aws_vpc.PubPrivateVPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.InternetGateway.id
  }
}

# Associate public subnets with public route table
resource "aws_route_table_association" "PublicSubnet1RouteTableAssociation" {
  subnet_id      = aws_subnet.PublicSubnet1.id
  route_table_id = aws_route_table.PublicRouteTable.id
}

resource "aws_route_table_association" "PublicSubnet2RouteTableAssociation" {
  subnet_id      = aws_subnet.PublicSubnet2.id
  route_table_id = aws_route_table.PublicRouteTable.id
}

resource "aws_route_table_association" "PublicSubnet3RouteTableAssociation" {
  subnet_id      = aws_subnet.PublicSubnet3.id
  route_table_id = aws_route_table.PublicRouteTable.id
}

# Create a security group
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Security group for web servers"

  vpc_id = aws_vpc.PubPrivateVPC.id  # Use the same VPC ID

  # Inbound rule example: allow HTTP traffic from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound rule example: allow SSH traffic from a specific IP range
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.10.0.0/16"]  # Replace with your specific IP range
  }

  # Outbound rule example: allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-sg"
  }
}

# Output the ID of the security group
output "web_security_group_id" {
  value = aws_security_group.web_sg.id
}

# Create RDS subnet group using private subnets
resource "aws_db_subnet_group" "main" {
  name        = "main-subnet-group"
  description = "Main RDS subnet group"
  subnet_ids  = [
    aws_subnet.PrivateSubnet1.id,
    aws_subnet.PrivateSubnet2.id,
    aws_subnet.PrivateSubnet3.id
  ]

  tags = {
    Name = "main-subnet-group"
  }
}

# Allocate Elastic IP address for NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

# Create a single NAT Gateway for private subnets
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.PublicSubnet1.id  # Use one of the public subnets for NAT Gateway

  tags = {
    Name = "NatGateway"
  }
}

# Create private route table and route traffic through NAT Gateway
resource "aws_route_table" "PrivateRouteTable" {
  vpc_id = aws_vpc.PubPrivateVPC.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name = "PrivateRouteTable"
  }
}

# Associate private subnets with private route table
resource "aws_route_table_association" "PrivateSubnet1RouteTableAssociation" {
  subnet_id      = aws_subnet.PrivateSubnet1.id
  route_table_id = aws_route_table.PrivateRouteTable.id
}

resource "aws_route_table_association" "PrivateSubnet2RouteTableAssociation" {
  subnet_id      = aws_subnet.PrivateSubnet2.id
  route_table_id = aws_route_table.PrivateRouteTable.id
}

resource "aws_route_table_association" "PrivateSubnet3RouteTableAssociation" {
  subnet_id      = aws_subnet.PrivateSubnet3.id
  route_table_id = aws_route_table.PrivateRouteTable.id
}
