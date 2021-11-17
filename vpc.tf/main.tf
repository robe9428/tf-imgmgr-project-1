resource "aws_vpc" "imgmgr_common_vpc" {
  cidr_block = var.vpc_cidr
}


resource "aws_subnet" "private-subnets" {
  vpc_id     = aws_vpc.imgmgr_common_vpc.id
  count      = length(var.azs)
  cidr_block = element(var.private-subnets , count.index)
  availability_zone = element(var.azs , count.index)

  tags = {
    Name = "private-subnet-${count.index+1}"
  }
}

resource "aws_subnet" "public-subnets" {
  vpc_id     = aws_vpc.imgmgr_common_vpc.id
  count      = length(var.azs)
  cidr_block = element(var.public-subnets , count.index)
  availability_zone = element(var.azs , count.index)

  tags = {
    Name = "public-subnet-${count.index+1}"
  }
}

resource "aws_eip" "nat-eip" {
  count    = length(var.azs)
  vpc      = true

  tags = {
    Name   = "EIP--${count.index+1}"
  }
}

resource "aws_internet_gateway" "imgmgr-igw" {
  vpc_id = aws_vpc.imgmgr_common_vpc.id

  tags = {
    Name = "prod-igw"
  }
}

resource "aws_nat_gateway" "imgmgr-nat-gateway" {
  count = length(var.azs)
  allocation_id = element(aws_eip.nat-eip.*.id , count.index)
  subnet_id     = element(aws_subnet.public-subnets.*.id , count.index)

  tags = {
    Name = "NAT-GW--${count.index+1}"
  }
}

#route table for public subnet
resource "aws_route_table" "imgmgr-public-rtable" {
  vpc_id = aws_vpc.imgmgr_common_vpc.id

  tags = {
    Name = "imgmgr-public-rtable"
  }
}

#route table for private subnet
resource "aws_route_table" "imgmgr-private-1-rtable" {
  vpc_id = aws_vpc.imgmgr_common_vpc.id

  tags = {
    Name = "imgmgr-private-1-rtable"
  }
}

resource "aws_route_table" "imgmgr-private-2-rtable" {
  vpc_id = aws_vpc.imgmgr_common_vpc.id

  tags = {
    Name = "imgmgr-private-2-rtable"
  }
}

#route table association public subnets
resource "aws_route_table_association" "public-subnet-association" {
  count          = length(var.public-subnets)
  subnet_id      = element(aws_subnet.public-subnets.*.id , count.index)
  route_table_id = aws_route_table.imgmgr-public-rtable.id
}

#add routes to public-rtable this is just for testing
resource "aws_route" "imgmgr-public-rtable" {
  count                     = length(var.public-subnets)
  route_table_id            = aws_route_table.imgmgr-public-rtable.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id                = aws_internet_gateway.imgmgr-igw.id
}

#route table association private subnets
resource "aws_route_table_association" "private-subnet-association-1" {
  subnet_id                 = "subnet-066b2847bb53ca658"
  route_table_id            = aws_route_table.imgmgr-private-1-rtable.id
}

resource "aws_route_table_association" "private-subnet-association-2" {
  subnet_id                 = "subnet-0135d39fa2a9b9113"
  route_table_id            = aws_route_table.imgmgr-private-2-rtable.id
}

#add routes to private-rtable this is just for testing
resource "aws_route" "imgmgr-private-rtable-1" {
  route_table_id            = aws_route_table.imgmgr-private-1-rtable.id
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id            = var.nat-gw-1
}

resource "aws_route" "imgmgr-private-rtable-2" {
  route_table_id            = aws_route_table.imgmgr-private-2-rtable.id
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id            = var.nat-gw-2
}
