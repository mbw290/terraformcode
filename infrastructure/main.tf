provider "aws" {
  region  = var.region
  profile = var.profile
}

resource "aws_vpc" "mw" {
  cidr_block       = var.vpccidr
  instance_tenancy = "default"
}

resource "aws_subnet" "mattssubnets" {
  for_each = var.mysubnets
  vpc_id     = "${aws_vpc.mw.id}"
  availability_zone = var.availability_zone
  cidr_block = each.value
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.mw.id}"
}

resource "aws_eip" "byoip-ip" {
  vpc              = true
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = "${aws_eip.byoip-ip.id}"
  subnet_id     = "${aws_subnet.mattssubnets["public"].id}"
}

resource "aws_route_table" "prir" {
  vpc_id = "${aws_vpc.mw.id}"
  route {
    cidr_block = var.home_cidr
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
  subnet_id      = "${aws_subnet.mattssubnets["private"].id}"
  route_table_id = "${aws_route_table.prir.id}"
}

resource "aws_route_table_association" "b" {
  subnet_id      = "${aws_subnet.mattssubnets["public"].id}"
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

resource "aws_instance" "mattsec2"{
  for_each = var.amis
  ami      = each.value
  instance_type = "t2.micro"
  key_name = var.ec2_keys
  subnet_id      = "${aws_subnet.mattssubnets["private"].id}"

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

output rhel8ip {
  value = "${aws_instance.mattsec2["rhel8"].private_ip}"
}

output al2ip {
  value = "${aws_instance.mattsec2["al2"].private_ip}"
}

output cg {
  value = "${aws_customer_gateway.customer_gateway.id}"
}

output pubip {
  value = "${aws_nat_gateway.ngw.public_ip}"
}
