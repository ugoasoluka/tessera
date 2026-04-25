module "vpc" {
  source = "./modules/vpc"

  availability_zones = ["us-east-2a", "us-east-2b"]

  settings = {
    main = {
      name = "tessera"
      cidr = "10.0.0.0/16"
    }
    us-east-2a = {
      cidr_public  = "10.0.0.0/24"
      cidr_private = "10.0.10.0/24"
      cidr_data    = "10.0.20.0/24"
    }
    us-east-2b = {
      cidr_public  = "10.0.1.0/24"
      cidr_private = "10.0.11.0/24"
      cidr_data    = "10.0.21.0/24"
    }
  }

  tags = local.tags
}