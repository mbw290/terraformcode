provider "aws" {
  region = "us-west-2"
}

variable "public_ip" {
  type = string
}

resource "aws_vpc" "mw" {
  cidr_block       = "172.16.0.0/16"
  instance_tenancy = "default"
}

resource "aws_subnet" "public" {
  vpc_id            = "${aws_vpc.mw.id}"
  availability_zone = "us-west-2a"
  cidr_block        = "172.16.0.0/24"
}
resource "aws_subnet" "private" {
  vpc_id            = "${aws_vpc.mw.id}"
  availability_zone = "us-west-2a"
  cidr_block        = "172.16.1.0/24"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.mw.id}"
}


resource "aws_eip" "byoip-ip" {
  vpc              = true
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = "${aws_eip.byoip-ip.id}"
  subnet_id     = "${aws_subnet.public.id}"
}

resource "aws_route_table" "prir" {
  vpc_id = "${aws_vpc.mw.id}"
  route {
    cidr_block = "192.168.1.0/24"
    gateway_id = "${aws_vpn_gateway.vpn_gateway.id}"
  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.ngw.id}"
  }
}

resource "aws_route_table" "pubr" {
  vpc_id = "${aws_vpc.mw.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = "${aws_subnet.private.id}"
  route_table_id = "${aws_route_table.prir.id}"
}

resource "aws_route_table_association" "b" {
  subnet_id      = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.pubr.id}"
}

resource "aws_vpn_gateway" "vpn_gateway" {
  vpc_id = "${aws_vpc.mw.id}"
}

resource "aws_customer_gateway" "customer_gateway" {
  ip_address = var.public_ip
  type = "ipsec.1"
  bgp_asn    = 65000
}

resource "aws_vpn_connection" "main" {
  vpn_gateway_id      = "${aws_vpn_gateway.vpn_gateway.id}"
  customer_gateway_id = "${aws_customer_gateway.customer_gateway.id}"
  type                = "ipsec.1"
  static_routes_only  = true
}

resource "aws_vpn_connection_route" "home" {
  destination_cidr_block = "192.168.1.0/24"
  vpn_connection_id      = "${aws_vpn_connection.main.id}"
}

resource "aws_instance" "mattec2" {
  ami = "ami-0d6621c01e8c2de2c"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.private.id}"
  key_name = "mw-keys"
  vpc_security_group_ids = "${aws_security_group.allow_all.*.id}"
}

resource "aws_instance" "mattrhel8" {
  ami = "ami-02f147dfb8be58a10s"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.private.id}"
  key_name = "mw-keys"
  vpc_security_group_ids = "${aws_security_group.allow_all.*.id}"
}

resource "aws_security_group" "allow_all" {
  name        = "allow_all"
  description = "Allow all inbound traffic"
  vpc_id      = "${aws_vpc.mw.id}"

  ingress {
    description = "all from all"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
 
  }
}
