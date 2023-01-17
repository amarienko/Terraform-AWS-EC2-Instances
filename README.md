<p align="left">
    <a href="https://developer.hashicorp.com/terraform/downloads" alt="Terraform">
    <img src="https://img.shields.io/badge/terraform-%3E%3D1.3-blueviolet" /></a>
    <a href="https://opensource.org/licenses/MIT" alt="License">
    <img src="https://img.shields.io/github/license/amarienko/Terraform-AWS-EC2-Instances?color=yellow" /></a>
</p>

# Terraform AWS EC2 Instances
Terraform module for creating AWS EC2 instances. This module is designed to provide the ability to create instances of various types, according to the specified parameters.
The module was developed in order to be able to create instances in a complex way, of various types, with different configuration parameters and the ability to use `for_each` loop when calling the module.

The module supports the creation of instances of two types `Linux` and `Windows`. 

<h3 id="usage">Module Usage</h3>

To use the module you need to add the module definition block in the root module. More detailed information about the parameters passed to the module is described below and in the module [Inputs](#inputs) section.

The main parameters passed to the module are described in the input variables `ec2_instance_type` (indicates the type of instance being created) and `ec2_config_parameters` (describes the configuration of the instance(s)).

In the root module, you must set a variable (input or local) (type `map()`) that includes parameters for calling the module.

<h5 id="ec2_parameters">Main variable definition example</h5>

```hcl
locals {
  /*
    Definition of instances parameters
  */
  ec2_parameters = {
    "t2.micro" = [
      {
        qty  = 2
        tier = "public"
        type = "main"
        azs  = ["eu-west-1a", "eu-west-1c", ]
      },
      {
        qty         = 1
        tier        = "private"
        type        = "nat"
        azs         = ["eu-west-1b", ]
        volume_size = 10
        volume_type = "gp3"
        ami         = "ami-0fe0b2cf0e1f25c8a"
        os          = "linux"
        name        = "amazon"
      },
    ],
    "t3.nano" = [
      {
        qty          = 1
        tier         = "private"
        type         = "main"
        azs          = ["eu-west-1a", ]
        encrypted    = true
        os           = "linux"
        distribution = "debian"
      },
    ]
  }
}
```
Calling a module with a `for_each` loop based on the `local.ec2_parameters` local variable above.

```hcl
/*
  EC2
*/
module "ec2_instances" {
  for_each = local.ec2_parameters
  source   = "github.com/amarienko/Terraform-AWS-EC2-Instances"

  instances_distribution = "manual"

  ec2_instance_type           = each.key
  ec2_config_parameters_index = index(keys(local.ec2_parameters), each.key)
  ec2_config_parameters       = each.value
}
```

Each key is passed to the module as the `ec2_instance_type` module variable, the value of each key as the `ec2_config_parameters` module variable. The module will be called twice. The first time to create three instances of type `t2.micro`, the second time to create an instance of type `t3.nano`.

The values of each key are a list of objects that describe the parameters of the instance(s).

Selecting an AMI to deploy an instance can be done in three ways:

- according to the default values. The default values are described in the variables `ami_selection_map_linux_default` and `ami_selection_map_windows_default` for each of the supported platforms.
- based on the specified AMI. The AMI ID must be specified in the `ami` subparameter. In addition to the AMI, the platform/OS subparameter `os` must be specified.
- setting the type of OS and distribution. In this case, the choice of AMI for deployment is based on the search parameters specified in the variables `ami_selection_map_linux_main`, `ami_selection_map_windows_main`, `ami_selection_map_linux_user` and `ami_selection_map_windows_user` for each of the supported platforms (see example below).

<h5 id="ami_selection">Example of defining a variable describing search parameters for selecting AMI</h5>

```hcl
/*
  EC2
*/
module "ec2-instances" {
  for_each = local.ec2_parameters
  source   = "github.com/amarienko/Terraform-AWS-EC2-Instances"
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

You can use one of the methods or a combination as in the example [above](#ec2_parameters). 

Distribution of instances between AZs/Subnets can be done dynamically or according to a given condition. If the value of the `instances_distribution` variable is set to `"random"` AZ is selected randomly, if the value of the `instances_distribution` parameter is set to `"manual"` (default value) instances are distributed according to the AZs specified in the `azs` subparameter. The number of AZs specified must match the number of instances in the `qty` subparameter.

If the second method is used (AMI is specified in the input parameter), you can verify the image and check its presence in the AWS AMI registry. To use this functionality, the `ec2_ami_verify` variable must be set to `true` (default is `false`). Additionally, the `ec2_ami_owners` parameter can be set to filter image owners in the registry. The default is `["amazon", ]`.

For each instance or multiple instances (`qty` subparameter), you can specify the type (`volume_type` subparameter) and size (subparameter `volume_size`, in GB) of the volume (by default, the AMI parameters from the image description are used), as well as set the encryption (subparameter `encrypted`) flag (by default, false).


<h3 id="inputs">Inputs</h3>

| Name | Description | Type |
|------|-------------|:------:|
| all\_tags | (Optional) User defined map of tags to add to all resources | `map(string)` |
| domain | (Optional) User defined objects tree | `string` |
| vpc\_name | (Required) VPC name | `string` |
| enable\_ipv6 | (Required) Enable IPv6 support | `bool` |
| ssh\_key\_pair\_name | (Required) AWS SSH key pair name (for Linux instances) | `string` |
| instances\_distribution  | (Required) Instances distribution method. Specifies how the instances are allocated relative to the subnet/AZs. Available options: 'manual' or 'random' | `string` |
| ec2\_instance_type | (Required) AWS EC2 Instance Type | `string` |
| ec2\_os\_family\_default | (Required) EC2 instance OS family. Available options: 'linux' or 'windows' | `string` |
| ec2\_config\_parameters\_index | (Required) Index of configuration set | `number` |
| ec2\_config\_parameters | (Required) Instances initial parameters. List, each element of which describes the parameters of the created instance(s) | `list(object(any))` |
| ec2\_ami\_verify | (Optional) Checking the AMIs specified in the configuration | `bool` |
| ec2\_ami\_owners | (Optional) List of AMIs owners required for image verification | `list(string)` |
| ec2\_inventory\_file | (Optional) Creating inventory file in `Ansible` format | `bool` |
| ec2\_os\_names\_map | (Required) OS full names to short names map | `map(string)` |
| ami\_selection\_map\_linux\_default | (Required) Describes default parameters for searching and filtering the results of the desired Linux AMI | `map(object(string))` |
| ami\_selection\_map\_linux\_main | (Optional) Describes static parameters for searching and filtering the results of the desired Linux AMIs | `map(object(string))` |
| ami\_selection\_map\_linux\_user | (Optional) Describes user defined parameters for searching and filtering the results of the desired Linux AMIs | `map(object(string))` |
| ami\_selection\_map\_windows\_default | (Required) Describes default parameters for searching and filtering the results of the desired Windows AMI | `map(object(string))` |
| ami\_selection\_map\_windows\_main | (Optional) Describes static parameters for searching and filtering the results of the desired Windows AMIs | `map(object(string))` |
| ami\_selection\_map\_windows\_user | (Optional) Describes user defined parameters for searching and filtering the results of the desired Windows AMIs | `map(object(string))` |

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
