output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "sg_apollo_id" {
  value = aws_security_group.sg_apollo.id
}

output "sg_elk_id" {
  value = aws_security_group.sg_elk.id
}