output "vpc_id" {
  value = aws_vpc.imgmgr_common_vpc.id
}

output "public_subnet_id" {
  value = [aws_subnet.public-subnets.*.id]
}

output "private_subnet_id" {
  value = [aws_subnet.private-subnets.*.id]
}

output "nat_gw_id" {
  value = [aws_nat_gateway.imgmgr-nat-gateway.*.id]
}
