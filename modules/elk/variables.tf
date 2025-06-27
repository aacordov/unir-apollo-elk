variable "vpc_id" { type = string }
variable "subnet_id" { type = string }
variable "key_pair_name" { type = string }
variable "instance_type" { type = string }
variable "ami_id" { type = string }
variable "security_group_id" {}
variable "user_data" {}
variable "allowed_ports" {
  description = "Lista de puertos TCP entrantes permitidos"
  type        = list(number)
}