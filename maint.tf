terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
  token      = var.token
}

# 1. Red (VPC + subred pública + IGW + tabla de rutas)
module "network" {
  source = "./modules/network"

  vpc_cidr_block     = var.vpc_cidr
  public_subnet_cidr = var.subnet_cidr_public
}

# 2. ELK stack
module "elk_stack" {
  source = "./modules/elk"

  vpc_id            = module.network.vpc_id
  subnet_id         = module.network.public_subnet_id
  key_pair_name     = var.key_pair_name
  instance_type     = "t3.medium"
  ami_id            = var.elk_ami
  security_group_id = module.network.sg_elk_id

  user_data = templatefile("${path.module}/templates/elk.sh.tpl",{})

  # Puertos críticos de ELK
  allowed_ports = [22, 5601, 9200, 5044] # SSH + Kibana + ES + Beats
}

# 3. Apollo-Server
module "apollo_server" {
  source = "./modules/apollo"

  vpc_id            = module.network.vpc_id
  subnet_id         = module.network.public_subnet_id
  key_pair_name     = var.key_pair_name
  instance_type     = var.instance_type
  ami_id            = var.apollo_ami
  security_group_id = module.network.sg_apollo_id

  user_data = templatefile("${path.module}/templates/apollo.sh.tpl", {
    elk_ip = module.elk_stack.private_ip
  })

  # Puertos expuestos (security group)
  allowed_ports = [22, 80, 443, 4000] # HTTP/S + Apollo
}