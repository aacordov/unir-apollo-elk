#Provider
region     = "us-east-1"
access_key = ""
secret_key = ""
token      = ""

# Module Network
source_module_network = "./modules/network"
vpc_cidr              = "10.0.0.0/16"
subnet_cidr_public    = "10.0.10.0/27"

key_pair_name = "apollo-elk"
instance_type = "t2.micro"

# Module EC2_ELK
elk_ami = "ami-020cba7c55df1f615"
elk_ip  = ""

# Module EC2_Apollo
apollo_ami = "ami-020cba7c55df1f615"