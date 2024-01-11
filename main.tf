locals {
  # Target for testing through VPCe
  vpce_endpoint = aws_vpc_endpoint.nlb.dns_entry[0].dns_name

  # Target for testing without VPCe (direct to NLB))
  nlb_endpoint  = module.without_vpce.nlb_hostname
}

module "client_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "vcpe-nlb-alb-client"
  cidr = "10.1.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.1.1.0/24", "10.1.2.0/24"]
  public_subnets  = ["10.1.101.0/24", "10.1.102.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false
}

module "provider_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "vcpe-nlb-alb-provider"
  cidr = "10.2.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.2.1.0/24", "10.2.2.0/24"]
  public_subnets  = ["10.2.101.0/24", "10.2.102.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false
}

# Provision an NLB/ALB pair in the provider VPC. This one will receive traffic
# through a VPC endpoint.
module "with_vpce" {
  source = "./modules/service"

  prefix = "y"

  vpc_id = module.provider_vpc.vpc_id
  public_subnets = module.provider_vpc.public_subnets
  cidr_blocks = [module.provider_vpc.vpc_cidr_block]
}

# Provision an NLB/ALB pair in the provider VPC. This one will receive traffic
# directly from clients (not through a VPC endpoint)
module "without_vpce" {
  source = "./modules/service"

  prefix = "n"

  vpc_id = module.provider_vpc.vpc_id
  public_subnets = module.provider_vpc.public_subnets
  cidr_blocks = [module.provider_vpc.vpc_cidr_block]
}

resource "aws_security_group" "vpce" {
  name        = "vpce-nlb-alb-vpce"
  description = "vpce-nlb-alb-vpce VPCe Security Group"
  vpc_id      = module.client_vpc.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "vpce_allout" {
  type              = "egress"
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 0
  security_group_id = aws_security_group.vpce.id
}

resource "aws_security_group_rule" "vpce_in" {
  type              = "ingress"
  protocol          = "tcp"
  cidr_blocks       = module.client_vpc.private_subnets_cidr_blocks
  from_port         = 80
  to_port           = 80
  security_group_id = aws_security_group.vpce.id
}

# Provision a VPC endpoint in the provider VPC
resource "aws_vpc_endpoint" "nlb" {
  vpc_id              = module.client_vpc.vpc_id
  service_name        = module.with_vpce.vpc_endpoint_service_name
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = false

  subnet_ids = module.client_vpc.private_subnets

  security_group_ids = [
    aws_security_group.vpce.id,
  ]

  tags = {
    Name = "vpce-nlb-alb-vpce"
  }
}

# Generates load against the NLB/ALB pair through the VPC endpoint
module "vpce_load_generator" {
  source = "./modules/load-generator"

  name = "vpce"
  vpc_id = module.client_vpc.vpc_id
  private_subnets = module.client_vpc.private_subnets
  ami = data.aws_ami.al2.id
  endpoint = local.vpce_endpoint
}

# Generates load against the NLB/ALB pair directly (not through the VPC endpoint)
module "nlb_load_generator" {
  source = "./modules/load-generator"

  name = "nlb"
  vpc_id = module.provider_vpc.vpc_id
  private_subnets = module.provider_vpc.private_subnets
  ami = data.aws_ami.al2.id
  endpoint = local.nlb_endpoint
}
