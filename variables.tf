# Provider
variable "region" {
  description = "region"
  type        = string
  sensitive   = true
}

variable "access_key" {
  description = "access_key"
  type        = string
  sensitive   = true
}

variable "secret_key" {
  description = "secret_key"
  type        = string
  sensitive   = true
}

variable "token" {
  description = "token"
  type        = string
  sensitive   = true
}

# Module Network
variable "source_module_network" {}
variable "vpc_cidr" {}
variable "subnet_cidr_public" {}

# Module Apollo
variable "key_pair_name" {
  description = "Nombre del key pair SSH existente"
  type        = string
}

variable "instance_type" {
  description = "Tipo por defecto de las instancias"
  type        = string
}

variable "apollo_ami" {
  description = "AMI para el servidor Apollo"
  type        = string
}

variable "elk_ami" {
  description = "AMI para el servidor ELK"
  type        = string
}

variable "elk_ip" {
  description = "Ip privada ELK"
  type        = string
}