#####################################################################################
## Syntax of how to create resources.
# resource "<provider>_<resource_type>" "name" {
#     config options...
#     key = "value"
#     key2 = "another_value"
# }
#####################################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  access_key = "my-access-key"
  secret_key = "my-secret-key"
}

# Create the VPC.
resource "aws_vpc" "webserver_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "production"
  }
}

# Create the gateway.
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.webserver_vpc.id

  tags = {
    Name = "prod-gateway"
  }
}

# Create a route table.
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.webserver_vpc.id

  route {
    cidr_block = "0.0.0.0/0" # All internet trafic will be be sent to where the route points.
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "prod-route"
  }
}

# Create the subnet.
resource "aws_subnet" "webserver_subnet" {
  vpc_id     = aws_vpc.webserver_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "prod-subnet"
  }
}

# Associate subnet with the route table.
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.webserver_subnet.id
  route_table_id = aws_route_table.prod-route-table.id
}

# Create security group to allow port 22, 80, 443
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.webserver_vpc.id

  tags = {
    Name = "allow_web"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_ipv4_port_22" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv4         = aws_vpc.webserver_vpc.cidr_block
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow_ipv6_port_22" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv6         = aws_vpc.webserver_vpc.ipv6_cidr_block
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow_ipv4_port_80" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv4         = aws_vpc.webserver_vpc.cidr_block
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_ipv6_port_80" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv6         = aws_vpc.webserver_vpc.ipv6_cidr_block
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_ipv4_port_443" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv4         = aws_vpc.webserver_vpc.cidr_block
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "allow_ipv6_port_443" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv6         = aws_vpc.webserver_vpc.ipv6_cidr_block
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv6" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Create a network interface with an ip in the subnet that was created above.
resource "aws_network_interface" "webserver_nic" {
  subnet_id       = aws_subnet.webserver_subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

# Assign an elastic IP to the network interface.
resource "aws_eip" "one" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.webserver_nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [ aws_internet_gateway.gw ]
}

# Create Ubuntu server and install/enable apache2.
resource "aws_instance" "webserver" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  tags = {
    Name = "ubuntu"
  }
}
