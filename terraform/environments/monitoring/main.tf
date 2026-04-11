# Monitoring Environment

module "vpc" {
  source             = "../../modules/vpc"
  environment        = "monitoring"
  project_name       = "unified-observability"
  vpc_cidr           = "10.0.0.0/16"
  public_subnet_cidr = "10.0.1.0/24"
  aws_region         = "ap-south-2"
}

module "ec2" {
  source       = "../../modules/ec2"
  environment  = "monitoring"
  project_name = "unified-observability"
  vpc_id       = module.vpc.vpc_id
  subnet_id    = module.vpc.public_subnet_id
  ami_id       = var.ami_id
  allowed_cidr = "0.0.0.0/0"
}