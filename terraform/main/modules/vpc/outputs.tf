output "id" {
  value       = aws_vpc.vpc.id
  description = "VPC ID"
}

output "cidr" {
  value       = aws_vpc.vpc.cidr_block
  description = "VPC CIDR"
}

output "public_subnet_ids" {
  value       = { for k, v in aws_subnet.public : k => v.id }
  description = "Public subnet IDs by AZ"
}

output "public_subnet_cidrs" {
  value       = { for k, v in aws_subnet.public : k => v.cidr_block }
  description = "Public subnet CIDRs by AZ"
}

output "private_subnet_ids" {
  value       = { for k, v in aws_subnet.private : k => v.id }
  description = "Private subnet IDs by AZ"
}

output "private_subnet_cidrs" {
  value       = { for k, v in aws_subnet.private : k => v.cidr_block }
  description = "Private subnet CIDRs by AZ"
}

output "nat_gateway_public_ips" {
  value       = { for k, v in aws_nat_gateway.nat_gw : k => v.public_ip }
  description = "NAT Gateway public IPs by AZ"
}

output "data_subnet_ids" {
  value       = { for k, v in aws_subnet.data : k => v.id }
  description = "Data subnet IDs by AZ"
}

output "data_subnet_cidrs" {
  value       = { for k, v in aws_subnet.data : k => v.cidr_block }
  description = "Data subnet CIDRs by AZ"
}