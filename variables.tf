# Variables declaration
variable "all_tags" {
  description = "Global tags for each resource"
  type        = map(string)
  default     = {}
}

variable "domain" {
  description = "Full resources name suffix"
  type        = string
  nullable    = true
  default     = ""
}

variable "vpc_name" {
  description = "VPC Name"
  nullable    = false
  type        = string
}

variable "enable_ipv6" {
  description = "Enable IPv6 support"
  type        = bool
  default     = false
}

variable "ssh_key_pair_name" {
  description = "Unix/Linux ssh-key pair name"
  type        = string
  nullable    = false

  validation {
    condition = (
      startswith(var.ssh_key_pair_name, "ssh-") &&
      length(var.ssh_key_pair_name) == 17
    )
    error_message = "Variable is set incorrectly!"
  }
}

variable "instances_distribution" {
  description = <<-DESCR
    Instances distribution method

    Specifies how the instances are allocated relative to the
    subnet/AZ
    Available options:
     "manual" - each instance is placed according to the order
                specified in the 'azs' configuration parameter
     "random" - instances are placed dynamically based on the
                randomized list
  DESCR
  type        = string
  nullable    = false
  default     = "manual"

  validation {
    condition     = contains(["manual", "random"], var.instances_distribution)
    error_message = "Available values 'manual' or 'random'!"
  }
}

variable "ec2_instance_type" {
  description = "EC2 Instance Type"
  type        = string
  default     = "t2.micro"
}

variable "ec2_os_family_default" {
  description = <<-DESCR
    Global EC2 instance OS family

    Available options:
      "linux"   - linux OS (default)
      "windows" - windows
  DESCR
  type        = string
  nullable    = false
  default     = "linux"

  validation {
    condition = (try(
      var.ec2_os_family_default != null) &&
      contains(["linux", "windows"], var.ec2_os_family_default)
    )
    error_message = "Available values 'linux' or 'windows'!"
  }
}

variable "ec2_config_parameters_index" {
  description = "Index of configuration set"
  type        = number
  default     = 0
}

variable "ec2_config_parameters" {
  description = <<-DESCR
    /*
      Instances initial parameters
    */

    List, each element of which describes the parameters of
    the created instance

    Examples:
    [
      {
        "instance"  = "t2.micro"
        "qty"  = 2
        "tier" = "private"
        "type" = "main"
        "azs"  = ["eu-west-1a", "eu-west-1c",]
      },
      {
        "instance"  = "t2.micro"
        "qty"  = 1
        "tier" = "public"
        "type" = "main"
        "azs"  = ["eu-west-1b",]
        "os"   = "windows"
      },
    ]

    [
      {
        "instance"  = "t3.nano"
        "qty"  = 2
        "tier" = "private"
        "type" = "nat"
        "azs"  = ["eu-west-1b", "eu-west-1c",]
      },
    ]
  DESCR

  nullable = false
  type = list(
    object(
      {
        instance               = optional(string, null),
        qty                    = number,
        tier                   = string,
        type                   = string,
        azs                    = list(string),
        encrypted              = optional(bool, false),
        iops                   = optional(number, 0),
        volume_size            = optional(number, null), # 8, minimum recommended default value 8GB
        volume_type            = optional(string, "gp2"),
        stop_protection        = optional(bool, false),
        termination_protection = optional(bool, false),
        ami                    = optional(string, null),
        os                     = optional(string, null), # "linux" or "windows", null by default
        name                   = optional(string, null),
        distribution           = optional(string, null)
      }
    )
  )

  validation {
    condition = try(
      length(var.ec2_config_parameters) > 0
    )
    error_message = "Initial parameters for creating at least one instance must be specified!"
  }
}

variable "ec2_ami_verify" {
  description = <<-DESCR
    Checking the AMIs specified in the configuration

    *  Note: Additional check slows down the module due to the
    creation of a list of images in the registry.
    To reduce the running time, the most accurate list of AMIs
    owners  should be  specified in the corresponding variable
    'ec2_ami_owners'
  DESCR

  type    = bool
  default = false
}

variable "ec2_ami_owners" {
  description = "List of AMIs owners required for image verification"
  type        = list(string)
  nullable    = false
  default     = ["amazon", ]
}

variable "ec2_inventory_file" {
  description = "Creating an inventory file"
  type        = bool
  nullable    = false
  default     = true
}

variable "ami_selection_map_linux_default" {
  description = <<-DESCR
    Describes default parameters for searching and filtering
    the results of the desired Linux AMI
  DESCR
  type = map(
    object(
      {
        description = optional(string, null)
        name        = string
        ver         = string
        substring   = optional(string, "*")
        arch        = string
        edition     = optional(string, "*")
        alias       = optional(string, "*")
        owner       = string
      }
    )
  )

  default = {
    default = {
      name    = "ubuntu"
      ver     = "22.04"
      arch    = "amd64"
      edition = "minimal"
      alias   = "jammy"
      owner   = "099720109477"
    },
  }

  validation {
    condition = (
      can(var.ami_selection_map_linux_default["default"]) &&
      try(length(var.ami_selection_map_linux_default["default"]) > 0)
    )
    error_message = "Default values must be set and have valid values!"
  }
}

variable "ami_selection_map_linux_main" {
  description = <<-DESCR
    The variable describes the parameters for searching and filtering
    the results of the desired Linux AMI
  DESCR
  type = map(
    object(
      {
        description = optional(string, null)
        name        = string
        ver         = string
        substring   = optional(string, "*")
        arch        = string
        edition     = optional(string, "*")
        alias       = optional(string, "*")
        owner       = string
      }
    )
  )

  default = {}

  validation {
    condition     = can(var.ami_selection_map_linux_main)
    error_message = "AMI selection variables must be declared!"
  }
}

variable "ami_selection_map_linux_user" {
  description = <<-DESCR
    Describes user defined parameters for searching and filtering
    the results of the desired Linux AMI

    Example:
      /*
        Ubuntu Linux 22.04 LTS (Jammy Jellyfish)
      */
      {
        ubuntu = {
          description = ""
          name        = "ubuntu"
          ver         = "22.04"
          arch        = "amd64"
          edition     = "server"
          alias       = "jammy"
          owner       = "099720109477"
        },
      }
    },
  DESCR
  type = map(
    object(
      {
        description = optional(string, null)
        name        = string
        ver         = string
        substring   = optional(string, "*")
        arch        = string
        edition     = optional(string, "*")
        alias       = optional(string, "*")
        owner       = string
      }
    )
  )

  default = {}

  validation {
    condition     = can(var.ami_selection_map_linux_user)
    error_message = "User AMI selection variables must be declared!"
  }
}

variable "ami_selection_map_windows_default" {
  description = <<-DESCR
    Describes default parameters for searching and filtering
    the results of the desired Windows AMI
  DESCR
  type = map(
    object(
      {
        description = optional(string, null)
        name        = string
        ver         = string
        subversion  = optional(string, "")
        lang        = string # Capitalized, `title()`
        edition     = string # Capitalized, `title()`
        owner       = string
      }
    )
  )

  default = {
    default = {
      name       = "Windows_Server"
      ver        = "2022"
      subversion = ""
      lang       = "English"
      edition    = "Core"
      owner      = "801119661308"
    },
  }

  validation {
    condition = (
      can(var.ami_selection_map_windows_default["default"]) &&
      try(length(var.ami_selection_map_windows_default["default"]) > 0)
    )
    error_message = "Default values must be set and have valid values!"
  }
}

variable "ami_selection_map_windows_main" {
  description = <<-DESCR
    The variable describes the parameters for searching and filtering
    the results of the desired Windows AMI
  DESCR
  type = map(
    object(
      {
        description = optional(string, null)
        name        = string
        ver         = string
        subversion  = optional(string, "")
        lang        = string # Capitalized, `title()`
        edition     = string # Capitalized, `title()`
        owner       = string
      }
    )
  )

  default = {}

  validation {
    condition     = can(var.ami_selection_map_windows_main)
    error_message = "AMI selection variables must be declared!"
  }
}

variable "ami_selection_map_windows_user" {
  description = <<-DESCR
    Describes user defined parameters for searching and filtering
    the results of the desired Windows AMI

    Example:
      /*
        Windows Server 2012 R2
      */
    "2012_r2" = {
      description = "Windows Server 2012 R2, English"
      name        = "Windows_Server"
      ver         = "2012"
      subversion  = "R2_RTM"
      lang        = "English"
      edition     = ""
      owner       = "801119661308"
    },
  DESCR
  type = map(
    object(
      {
        description = optional(string, null)
        name        = string
        ver         = string
        subversion  = optional(string, "")
        lang        = string # Capitalized, `title()`
        edition     = string # Capitalized, `title()`
        owner       = string
      }
    )
  )

  default = {}

  validation {
    condition     = can(var.ami_selection_map_windows_user)
    error_message = "User AMI selection variables must be declared!"
  }
}

variable "ec2_os_names_map" {
  description = "OS full names to short names map"
  type        = map(string)
  default = {
    ubuntu               = "uls"
    debian               = "deb"
    amazon               = "amzn"
    rhel                 = "rhel"
    rhel_ha              = "rhel_ha"
    suse                 = "sles"
    windows_servers_core = "ws-core"
    windows_servers_full = "ws-full"
  }
}

/*
  Currently disabled

variable "ec2_os_name" {
  description = <<-DESCR
    EC2 instance platform

    Available options:
      "default"     - Ubuntu (minimal)
      "ubuntu"      - Ubuntu
      "debian"      - Debian
      "amazon"      - Amazon
      "redhat"      - Red Hat
      "redhat-ha"   - Red Hat HA
      "suse"        - SUSE
      "windows"     - Windows
      "windows-sql" - Windows with SQL Server
  DESCR
  type        = string
  default     = "default"
}
*/
