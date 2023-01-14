<p align="left">
    <a href="https://developer.hashicorp.com/terraform/downloads" alt="Terraform">
    <img src="https://img.shields.io/badge/terraform-%3E%3D1.2-blueviolet" /></a>
    <a href="https://opensource.org/licenses/MIT" alt="License">
    <img src="https://img.shields.io/github/license/amarienko/Terraform-AWS-EC2-Instances?color=yellow" /></a>
</p>

# Terraform AWS EC2 Instances
Terraform module for creating AWS EC2 instances. This module is designed to provide the ability to create instances of various types, according to the specified parameters.

The module supports the creation of instances of two types `Linux` and `Windows`. 

<h3 id="usage">Module Usage</h3>

To use the module you need to add the following module definition block in the root module. This is a short example of a module definition, more detailed information about the parameters passed to the module is described in the module [Inputs](#inputs) section.

```hcl
/*
  EC2
*/
module "ec2-instances" {
  for_each = local.ec2_parameters
  source   = "github.com/amarienko/Terraform-AWS-EC2-Instances"

  vpc_name               = var.vpc_name
  enable_ipv6            = var.enable_ipv6
  instances_distribution = "manual"

  ec2_os_family_default       = "linux"
  ec2_ami_verify              = true
  ec2_ami_owners              = ["amazon", ]
  ec2_inventory_file          = true
  ec2_instance_type           = each.key
  ec2_config_parameters_index = index(keys(local.ec2_parameters), each.key)
  ec2_config_parameters       = each.value

  ssh_key_pair_name = module.ssh-keygen.ssh__01__key_name.key_pair_name

  all_tags = local.all_tags


  # AMIs selection variables
  ami_selection_map_linux_user = {
    amazon = {
      description = "amzn2-ami-kernel-5.10-hvm, Amazon Linux 2 Kernel 5.10 AMI 2.0"
      name        = "amzn2"
      ver         = "5.10"
      arch        = "x86_64"
      owner       = "137112412989"
    },
  }
}
```

<h3 id="inputs">Inputs</h3>

| Name | Description | Type | Default |
|------|-------------|:------:|:---------:|

<h3 id="outputs">Outputs</h3>

| Name | Description |
|------|-------------|
