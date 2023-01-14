<p align="left">
    <a href="https://developer.hashicorp.com/terraform/downloads" alt="Terraform">
    <img src="https://img.shields.io/badge/terraform-%3E%3D1.3-blueviolet" /></a>
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
|------|-------------|:------:|---------|
| all\_tags | (Optional) User defined map of tags to add to all resources | `map(string)` | `{}` |
| domain | (Optional) User defined objects tree | `string` | `""` |
| vpc\_name | (Required) VPC name | `string` ||
| enable\_ipv6 | (Required) Enable IPv6 support | `bool` | `false` |
| ssh\_key\_pair\_name | (Required) AWS SSH key pair name (for Linux instances) | `string` ||
| instances\_distribution  | (Required) Instances distribution method. Specifies how the instances are allocated relative to the subnet/AZs. Available options: 'manual' or 'random' | `string` | `"manual"` |
| ec2\_instance_type | (Required) AWS EC2 Instance Type | `string` | `"t2.micro"` |
| ec2\_os\_family\_default | (Required) EC2 instance OS family. Available options: 'linux' or 'windows' | `string` | `"linux"` |
| ec2\_config\_parameters\_index | (Required) Index of configuration set | `number` | `0` |
| ec2\_config\_parameters | (Required) Instances initial parameters. List, each element of which describes the parameters of the created instance(s) | `list(object(any))` ||
| ec2\_ami\_verify | (Optional) Checking the AMIs specified in the configuration | `bool` | `false` |
| ec2\_ami\_owners | (Optional) List of AMIs owners required for image verification | `list(string)` | `["amazon",]` |
| ec2\_inventory\_file | (Optional) Creating inventory file in `Ansible` format | `bool` | `true` |
| ec2\_os\_names\_map | (Required) OS full names to short names map | `map(string)` | <pre>{<br>&nbsp;&nbsp;ubuntu               = "uls"<br>&nbsp;&nbsp;debian               = "deb"<br>&nbsp;&nbsp;amazon               = "amzn"<br>&nbsp;&nbsp;rhel                 = "rhel"<br>&nbsp;&nbsp;rhel\_ha              = "rhel_ha"<br>&nbsp;&nbsp;suse                 = "sles"<br>&nbsp;&nbsp;windows\_servers\_core = "ws-core"<br>&nbsp;&nbsp;windows\_servers\_full = "ws-full"<br>}</pre> |
| ami\_selection\_map\_linux\_default | (Required) Describes default parameters for searching and filtering the results of the desired Linux AMI | `map(object(string))` | <pre>{<br>&nbsp;&nbsp;default = {<br>    description = ""<br>&nbsp;&nbsp;&nbsp;&nbsp;name        = "ubuntu"<br>&nbsp;&nbsp;&nbsp;&nbsp;ver         = "22.04"<br>&nbsp;&nbsp;&nbsp;&nbsp;arch        = "amd64"<br>&nbsp;&nbsp;&nbsp;&nbsp;edition     = "minimal"<br>&nbsp;&nbsp;&nbsp;&nbsp;alias       = "jammy"<br>&nbsp;&nbsp;&nbsp;&nbsp;owner       = "099720109477"<br>&nbsp;&nbsp;},<br>}</pre> |
| ami\_selection\_map\_linux\_main | (Optional) Describes static parameters for searching and filtering the results of the desired Linux AMIs | `map(object(string))` | `{}` |
| ami\_selection\_map\_linux\_user | (Optional) Describes user defined parameters for searching and filtering the results of the desired Linux AMIs | `map(object(string))` | `{}` |
| ami\_selection\_map\_windows\_default | (Required) Describes default parameters for searching and filtering the results of the desired Windows AMI | `map(object(string))` | <pre>{<br>&nbsp;&nbsp;default = {<br>&nbsp;&nbsp;&nbsp;&nbsp;name       = "Windows_Server"<br>&nbsp;&nbsp;&nbsp;&nbsp;ver        = "2022"<br>&nbsp;&nbsp;&nbsp;&nbsp;subversion = ""<br>&nbsp;&nbsp;&nbsp;&nbsp;lang       = "English"<br>&nbsp;&nbsp;&nbsp;&nbsp;edition    = "Core"<br>&nbsp;&nbsp;&nbsp;&nbsp;owner      = "801119661308"<br>&nbsp;&nbsp;},<br>}</pre> |
| ami\_selection\_map\_windows\_main | (Optional) Describes static parameters for searching and filtering the results of the desired Windows AMIs | `map(object(string))` | `{}` |
| ami\_selection\_map\_windows\_user | (Optional) Describes user defined parameters for searching and filtering the results of the desired Windows AMIs | `map(object(string))` | `{}` |

<h3 id="outputs">Outputs</h3>

| Name | Description |
|------|-------------|
| ec2\_\_00\_\_images\_linux | Details about the default AMI for Linux instances |
| ec2\_\_00__images\_windows | Details about the default AMI for Windows instances |
| ec2\_\_01\_\_network\_interfaces | Includes general information about created network interfaces: ID, MAC address, Security group(s), Subnet ID, Private DNS name, Private IP address and IPv6 address (if applicable) |
| ec2\_\_02\_\_instances | Includes general information about created EC2 instances: arn, Instance type, AZ, Subnet ID, Primary NIC ID, Public/Private DNS and IP address and IPv6 address (if applicable) |
| ec2\_\_03\_\_inventory | Inventory file ID and filename |

<h3 id="providers">Providers</h3>
| Name | Version |
|------|-------------|
| [aws](https://registry.terraform.io/providers/hashicorp/aws) | ~> 4.0 |
| [local](https://registry.terraform.io/providers/hashicorp/local) | ~> 2.2 |
| [null](https://registry.terraform.io/providers/hashicorp/null) | ~> 3.2 |
| [random](https://registry.terraform.io/providers/hashicorp/random) | ~> 3.0 |
