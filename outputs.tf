output "apollo_public_ip" {
  value = module.apollo_server.public_ip
}

output "elk_public_ip" {
  value = module.elk_stack.public_ip
}
