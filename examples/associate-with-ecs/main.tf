####################################################
# Data sources to get image, VPC and vswitch details
####################################################

data "alicloud_images" "ubuntu" {
  most_recent = true
  name_regex  = "^ubuntu_18.*64"
}

data "alicloud_vpcs" "default" {
  is_default = true
}

data "alicloud_instance_types" "default" {
  cpu_core_count    = 1
  memory_size       = 2
  availability_zone = data.alicloud_vswitches.default.vswitches.0.zone_id
}

data "alicloud_vswitches" "default" {
  ids = [data.alicloud_vpcs.default.vpcs.0.vswitch_ids.0]
}

####################################################################
# eip_ecs_security_group which is used as an argument in ecs_cluster
####################################################################

module "web_server_sg" {
  source = "alibaba/security-group/alicloud//modules/http-80"

  name                = "web-server"
  description         = "Security group for web-server with HTTP ports open within VPC"
  vpc_id              = data.alicloud_vpcs.default.ids.0
  ingress_cidr_blocks = ["10.10.0.0/16"]
}

################################################################
# ecs_cluster which is used as an argument in associate-with-ecs
################################################################

module "ecs_cluster" {
  source  = "alibaba/ecs-instance/alicloud"
  version = "~> 2.0"

  number_of_instances         = 2
  name                        = "my-ecs-cluster"
  use_num_suffix              = true
  image_id                    = data.alicloud_images.ubuntu.ids.0
  instance_type               = data.alicloud_instance_types.default.ids.0
  vswitch_id                  = data.alicloud_vpcs.default.vpcs.0.vswitch_ids.0
  security_group_ids          = [module.web_server_sg.this_security_group_id]
  associate_public_ip_address = false
  system_disk_category        = "cloud_ssd"
  system_disk_size            = 50
  tags = {
    Created     = "Terraform"
    Environment = "dev"
  }
}

########################################################
# eip full parameters associated with associate-with-ecs
########################################################

module "associate-with-ecs" {
  source = "../../modules/associate-with-ecs"

  create               = true
  number_of_eips       = 3
  name                 = "eip-ecs-example"
  bandwidth            = 5
  internet_charge_type = "PayByTraffic"
  instance_charge_type = "PostPaid"
  period               = 1

  # The number of instances created by calling the API. If this parameter is used, `number_of_eips` will be ignored.
  number_of_computed_instances = 2
  computed_instances = [
    {
      instance_ids  = module.ecs_cluster.this_instance_id
      instance_type = "EcsInstance"
      private_ips   = []
    }
  ]

  # ECS instances found by these conditions. If these parameter is used, `number_of_eips` will be ignored.
  name_regex        = "emr*"
  tags              = ""
  resource_group_id = ""
}