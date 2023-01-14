/*
                                     -
                                     -----                           -
                                     ---------                      --
                                     ---------  -                -----
                                      ---------  ------        -------
                                        -------  ---------  ----------
                                           ----  ---------- ----------
                                             --  ---------- ----------
   Terraform module for creating              -  ---------- -------
   AWS EC2 instances                             ---  ----- ---
                                                 --------   -
                                                 ----------
                                                 ----------
                                                  ---------
                                                      -----
                                                          -


*/


/*
  Checking that variables are set correctly and throwing an
  error if not
*/
resource "null_resource" "check_azs_distribution" {
  count = 1

  lifecycle {
    precondition {
      condition = (
        var.instances_distribution == "random" && sum([
          for v in var.ec2_config_parameters : v.qty
          ]
        ) > 0) || (
        var.instances_distribution == "manual" && sum([
          for v in var.ec2_config_parameters : v.qty
          ]) > 0 && !contains([
          for i, v in var.ec2_config_parameters : length(v.azs) == v.qty ? true : false
          ], false
        )
      )

      error_message = <<-ERR
        Init parameters for creating instances are set incorrectly!
      ERR
    }
  }
}

resource "null_resource" "check_config_parameters" {
  count = 1

  lifecycle {
    # must be removed, the check is performed at the variable level
    # "check os definition"
    precondition {
      condition = !contains([
        for v in var.ec2_config_parameters : (
          !contains(
            [
              "linux",
              "windows",
            ], v.os
          ) ? false : true
        )
        if v.os != null
        ], false
      )
      error_message = <<-ERR
        The 'os' parameter can only have supported values 'linux' or 'windows'
      ERR
    }

    # "check ami definition"
    precondition {
      condition = !contains([
        for v in var.ec2_config_parameters : (
          v.ami != null && v.os == null
        ) ? false : true
      ], false)
      error_message = <<-ERR
        Error in initial parameters! If Amazon Machine Image 'ami' is set to create
        an instance, the parameter 'os' must be specified!
      ERR
    }

    # "check distribution definition"
    precondition {
      condition = !contains([
        for v in var.ec2_config_parameters : (
          (v.distribution != null && v.os == null) || (
            v.os == "linux" && !contains(
              keys(merge(
                var.ami_selection_map_linux_default,
                var.ami_selection_map_linux_main,
                var.ami_selection_map_linux_user,
              )), v.distribution
            )) || (
            v.os == "windows" && !contains(
              keys(merge(
                var.ami_selection_map_windows_default,
                var.ami_selection_map_windows_main,
                var.ami_selection_map_windows_user,
              )), v.distribution
            )
          ) ? false : true
        )
        if v.distribution != null
      ], false)
      error_message = <<-ERR
        Error in initial parameters! If instance 'distribution' is set, the
        parameter 'os' must be specified and 'distribution' value must be in
        a predefined list!
      ERR
    }

  }
}

/*
  Initial local variables definition
*/
locals {
  separator         = ","
  eth_index_default = "0"

  # res: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-eni.html
  no_ipv6_instance_types = [
    "t1.micro",
    "m1.small",
    "m1.medium",
    "m1.large",
    "m1.xlarge",
    "m2.xlarge",
    "m2.2xlarge",
    "m2.4xlarge",
    "m3.medium",
    "m3.large",
    "m3.xlarge",
    "m3.2xlarge",
    "hs1.8xlarge",
    "g2.2xlarge",
    "g2.8xlarge",
    "cc2.8xlarge",
    "cr1.8xlarge",
    "c1.medium",
    "c1.xlarge",
  ]

  main_count = sum([for v in var.ec2_config_parameters : v.qty])

  /*
    AMIs selection variables
  */
  # ami_selection_map_linux = merge()
  # ami_selection_map_windows = merge()

  # Linux
  platform_linux = true
  distribution_map_linux = {
    for dist in concat(["default"], [
      for v in var.ec2_config_parameters : v.distribution if(
        v.distribution != null && v.os == "linux"
      )
      ]) : dist => lookup(
      merge(
        var.ami_selection_map_linux_default,
        var.ami_selection_map_linux_main,
        var.ami_selection_map_linux_user
      ), dist
      ) if contains(
      keys(merge(
        var.ami_selection_map_linux_default,
        var.ami_selection_map_linux_main,
        var.ami_selection_map_linux_user
      )), dist
    )
  }

  # Windows
  platform_windows = contains(
    concat([
      for v in var.ec2_config_parameters : v.os], tolist([var.ec2_os_family_default])
  ), "windows") ? true : false

  distribution_map_windows = {
    for dist in concat(["default"], [
      for v in var.ec2_config_parameters : v.distribution if(
        v.distribution != null && v.os == "windows"
      )
      ]) : dist => lookup(
      merge(
        var.ami_selection_map_windows_default,
        var.ami_selection_map_windows_main,
        var.ami_selection_map_windows_user
      ), dist
      ) if contains(
      keys(merge(
        var.ami_selection_map_windows_default,
        var.ami_selection_map_windows_main,
        var.ami_selection_map_windows_user
      )), dist
    )
  }
}


/*
  Getting registered AMI IDs for use
*/
data "aws_ami" "linux" {
  for_each           = local.distribution_map_linux
  most_recent        = true
  include_deprecated = false

  filter {
    /*
      Filters by distribution, excluding distributions with tag
      "Deep Learning AMI GPU *" and distributions with ".NET *"
      pre-installed and Linux with "SQL Server Std. Edition"
      {
        ubuntu      = "*ubuntu-jammy-22.04-amd64-server-*",
        debian      = "*debian-11-amd64-*",
        amzn_linux2 = "*amzn2-ami-kernel-5.10-*-x86_64-*",
        rhel        = "*RHEL-9.1.0_HVM-*-x86_64-*",
        rhel_ha     = "*RHEL_HA-9.1.0_HVM-*-x86_64-*",
        suse        = "*suse-sles-15-sp4-*-x86_64*",
      }
    */
    name = "name"
    values = [
      "*${each.value.name}-*${each.value.ver}${each.value.substring}-${each.value.arch}*${each.value.edition}*",
    ]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  owners = [
    each.value.owner
  ]

  depends_on = [
    null_resource.check_config_parameters,
  ]
}

data "aws_ami" "windows" {
  for_each           = local.distribution_map_windows
  most_recent        = true
  include_deprecated = false

  filter {
    /*
      Filters by windows "edition", include only 'core' and 'full'
      editions
    */
    name = "name"
    values = [
      "${each.value.name}-${each.value.ver}-*${each.value.subversion}*${title(
      each.value.lang)}-*${title(each.value.edition)}-Base*",
    ]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "platform"
    values = ["windows"]
  }

  owners = [
    each.value.owner
  ]

  depends_on = [
    null_resource.check_config_parameters,
  ]
}

/*
  Validation of user specified AMI IDs if the `ec2_ami_verify`
  parameter is set to true


  Step 1. Building list of AMI IDs matching to criteria based on
  the image owner or owner alias.
  Step 2. Checking if the user-specified ID is in the selected list
  of all AMIs
  Step 3. Additional check. Comparing the number of user-specified
  IDs with the number of verified IDs


  Note: Main owners IDs
  [
    "099720109477",  # Canonical
    "903794441882",  # Debian
    "137112412989",  # Amazon (Lnx)
    "309956199498",  # Red Hat, Inc.
    "013907871322",  # SUSE
    "801119661308",  # Amazon (Win)
  ]

  "amazon" owner alias "amazon" (does not cover 'Debian')
  - "image_owner_alias" = ""        for debian
  - "image_owner_alias" = "amazon"  for others base images
*/
data "aws_ami_ids" "all" {
  count  = var.ec2_ami_verify ? 1 : 0
  owners = var.ec2_ami_owners

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_ami" "specified" {
  for_each = var.ec2_ami_verify ? toset([
    for v in var.ec2_config_parameters : v.ami if v.ami != null
  ]) : []

  most_recent        = true
  include_deprecated = false

  filter {
    /*
      Filter based on the '--filters (list)' keys described here
      https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-images.html
    */
    name = "image-id"
    values = [
      each.value,
    ]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  lifecycle {
    precondition {
      condition     = contains(data.aws_ami_ids.all[0].ids, each.value)
      error_message = "Image '${each.value}' not found in AMI IDs selection list!"
    }
    /*
      Needs to be reviewed. An error occurs if the `data.aws_ami` has a
      null result.
      The error occurs before the lifecycle (postcondition) block.

      Error message:

        │ Error: Your query returned no results. Please change your search criteria
        │        and try again.
        │
        │   with data.aws_ami.specified["ami-"],

    postcondition {
      condition = try(each.value == self.id)
      error_message = "Image '${each.value}' not found!"
    }
    */
  }

  depends_on = [
    null_resource.check_config_parameters,
    data.aws_ami_ids.all,
  ]
}

resource "null_resource" "check_ami_specified" {
  count = var.ec2_ami_verify ? 1 : 0

  lifecycle {
    precondition {
      condition = try(
        (
          sum([
            for v in var.ec2_config_parameters : v.ami != null && v.ami != "" ? 1 : 0 if v.ami != null
            ]) == length(
            data.aws_ami.specified
          )
        )
      )
      error_message = <<-ERR
        The number of images specified in the configuration is not equivalent
        to the number of checked AMIs
      ERR
    }
  }

  depends_on = [
    null_resource.check_config_parameters,
    data.aws_ami.specified
  ]
}


/*
  Getting data for deployment
*/
data "aws_vpcs" "main" {
  # data.aws_vpcs.main.ids
  tags = {
    Name = var.vpc_name
  }
}

data "aws_vpc" "main" {
  # data.aws_vpc.main.id
  id = one(data.aws_vpcs.main.ids)

  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_availability_zones" "available" {
  # data.aws_availability_zones.available.names
  state = "available"
}

data "aws_subnets" "all" {
  # data.aws_subnets.selected.ids
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
}

data "aws_subnets" "selected" {
  # data.aws_subnets.selected.ids
  /*
    Warning: Deprecated Resource
    The `aws_subnet_ids` data source has been deprecated and will be
    removed in a future version. Use the aws_subnets data source
    instead.

    vpc_id = data.aws_vpc.main[0].id
  */
  count = length(var.ec2_config_parameters)

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  tags = {
    Tier = var.ec2_config_parameters[count.index].tier
    Type = var.ec2_config_parameters[count.index].type
  }
}

data "aws_subnet" "all" {
  # Each existed subnet details
  # data.aws_subnet.selected
  for_each = toset(data.aws_subnets.all.ids)

  id = each.value
}

/*
  Security groups selection
*/
data "aws_security_groups" "default" {
  # data.aws_security_groups.default.ids
  filter {
    name   = "group-name"
    values = ["default"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
}

data "aws_security_groups" "linux" {
  # data.aws_security_groups.linux.ids
  count = local.platform_linux ? 1 : 0

  filter {
    name   = "tag:Platform"
    values = ["lnx"] # replaced old "unx" tag
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
}

data "aws_security_groups" "windows" {
  # data.aws_security_groups.windows.ids
  count = local.platform_windows ? 1 : 0

  filter {
    name   = "tag:Platform"
    values = ["win"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
}


resource "random_shuffle" "subnets_selected" {
  count = var.instances_distribution == "random" ? length(
    data.aws_subnets.selected
  ) : 0

  input        = data.aws_subnets.selected[count.index].ids
  result_count = var.ec2_config_parameters[count.index].qty
}

resource "random_string" "confg_id" {
  keepers = {
    random_index = var.ec2_config_parameters_index
  }

  length      = 5
  special     = false
  lower       = true
  min_lower   = 2
  upper       = true
  min_upper   = 1
  numeric     = true
  min_numeric = 2
}

locals {
  /*
    Building a сonfiguration map
  */
  initial_subnets_distribution = var.instances_distribution == "manual" ? [
    for i, v in data.aws_subnets.selected : [
      for az in var.ec2_config_parameters[i].azs : join(",", [
        for s in v.ids : s if data.aws_subnet.all[s].availability_zone == az]
      )
    ]
    ] : var.instances_distribution == "random" ? [
    for i, v in random_shuffle.subnets_selected : v.result
  ] : []

  ami_default = try(
    var.ec2_os_family_default == "linux"
  ) ? data.aws_ami.linux["default"].id : data.aws_ami.windows["default"].id

  initial_config_map = [
    for i, v in var.ec2_config_parameters : [
      for q in range(v.qty) : {
        "instance" = v.instance != null ? v.instance : var.ec2_instance_type,
        "idx"      = q,
        "subnet"   = local.initial_subnets_distribution[i][q],
        # eq. `v.azs[q]`
        "az" = data.aws_subnet.all[
          local.initial_subnets_distribution[i][q]
        ].availability_zone,
        # eq. `v.tier`
        "tier" = data.aws_subnet.all[
          local.initial_subnets_distribution[i][q]
        ].tags.Tier,
        # eq. `v.type`
        "type" = data.aws_subnet.all[
          local.initial_subnets_distribution[i][q]
        ].tags.Type,
        "encrypted"              = v.encrypted,
        "iops"                   = v.iops,
        "volume_size"            = v.volume_size,
        "volume_type"            = v.volume_type,
        "termination_protection" = v.termination_protection,
        "stop_protection"        = v.stop_protection,
        /* 'ami' selection based on given parameters */
        "ami" = (v.ami != null ? v.ami : (
          v.distribution != null ? (
            v.os == "linux" ?
            try(
              lookup(data.aws_ami.linux, v.distribution)
            ).id :
            try(
              lookup(data.aws_ami.windows, v.distribution)
            ).id
            ) : (
            v.os != null ? (
              v.os == "linux" ?
              try(
                data.aws_ami.linux["default"]
              ).id :
              try(
                data.aws_ami.windows["default"]
              ).id
            ) : try(local.ami_default)
          ))
        ),
        "os"           = v.os != null ? v.os : var.ec2_os_family_default,
        "distribution" = v.distribution != null ? v.distribution : "",
    }]
  ]

  /*
    Final keys list
  */
  keys = [
    "instance",
    "idx",
    "subnet",
    "tier",
    "type",
    "az",
    "encrypted",
    "volume_size",
    "volume_type",
    "iops",
    "stop_protection",
    "termination_protection",
    "ami",
    "os",
    "distribution",
  ]

  configuration_data = {
    for index in range(local.main_count) : index => {
      for key in local.keys : key => split(",", join(",", [
        for i, v in local.initial_config_map : join(",", [
          for q in range(length(v)) : v[q][key]
        ])
      ]))[index]
    }
  }
}


/*
  Creation of network interfaces
*/
resource "aws_network_interface" "eni" {
  description = "instance eni"
  for_each    = local.configuration_data

  # VPC Subnet ID to launch in (Required)
  subnet_id = each.value.subnet

  # List of security group IDs to assign to the ENI (Optional)
  security_groups = each.value.tier == "public" ? (
    each.value.os == "linux" ? concat(
      data.aws_security_groups.default.ids,
      data.aws_security_groups.linux[0].ids
      ) : concat(
      data.aws_security_groups.default.ids,
      data.aws_security_groups.windows[0].ids
    )
  ) : data.aws_security_groups.default.ids

  # Number of IPv6 addresses to associate with the primary NIC
  ipv6_address_count = (
    var.enable_ipv6 &&
    !contains(local.no_ipv6_instance_types, var.ec2_instance_type)
  ) ? 1 : 0

  tags = merge(
    {
      Name = "eth${
        local.eth_index_default
        }.%{if each.value.os == "linux"}lnx%{else}win%{endif}${
        random_string.confg_id.keepers.random_index # var.ec2_config_parameters_index
        }${
        each.key
      }-${random_string.confg_id.result}"
      Resource = "eni"
      FullName = "eth${
        local.eth_index_default
        }.%{if each.value.os == "linux"}lnx%{else}win%{endif}${
        random_string.confg_id.keepers.random_index
        }${
        each.key
        }-${
        random_string.confg_id.result
        }.eni${var.domain
      }"
    },
    var.all_tags
  )

  lifecycle {
    /*
      Verifying IPv6 Protocol Support
    */

    precondition {
      condition = try(var.enable_ipv6 == true) ? (
        try(
          data.aws_vpc.main.ipv6_association_id != null ||
          data.aws_vpc.main.ipv6_association_id != ""
        ) ?
        # "ipv6 confg" = "yes" && "vpc ipv6 support" = "yes"
        true
        :
        # "ipv6 confg" = "yes" && "vpc ipv6 support" = "no"
        false
      ) : true # "ipv6 confg" = "no" && "vpc ipv6 support" = "any"

      error_message = <<-ERR
        VPC configuration must match the values of the variables!

        If IPv6 support is enabled VPC must support the IPv6 protocol
        and be associated with an IPv6 CIDR block.

        Variable value:
          'enable_ipv6'                  '${var.enable_ipv6}'
        VPC configuration:
          'ipv6_association_id'          '${data.aws_vpc.main.ipv6_association_id}'
          'ipv6_cidr_block'              '${data.aws_vpc.main.ipv6_cidr_block}'
      ERR
    }

    precondition {
      condition = (
        try(
          data.aws_subnet.all[each.value.subnet].assign_ipv6_address_on_creation == true
          ) ? (
          contains(
            local.no_ipv6_instance_types, var.ec2_instance_type
          ) ? false : true
        ) : true
      )
      error_message = <<-ERR
        Error in instance subnet settings! The specified instance type '${var.ec2_instance_type}'
        does not support IPv6, but the subnet '${each.value.subnet}' assigned
        to the instance will automatically assign an IPv6 address when the NIC is
        created.
      ERR
    }
  }

  depends_on = [
    null_resource.check_config_parameters,
    local.configuration_data,
    data.aws_vpc.main,
    data.aws_subnet.all,
    random_string.confg_id,
  ]
}

/*
  Optional to `aws_network_interface` `security_groups` list

# Attaching a security group to an ENI
resource "aws_network_interface_sg_attachment" "sg_attach_to_eni" {
  count = length(aws_network_interface.eni)

  # The ID of the security group (Required)
  security_group_id = ""

  # The ID of the network interface to attach to (Required)
  network_interface_id = aws_network_interface.eni[count.index].id

  depends_on = [
    null_resource.check_config_parameters,
    local.configuration_data,
    aws_network_interface.eni
  ]
}
*/

/*
  EC2
*/
resource "aws_instance" "ec2" {
  for_each = length(aws_network_interface.eni) > 0 ? local.configuration_data : {}

  ami           = each.value.ami
  instance_type = var.ec2_instance_type # each.value.instance

  /*
    Network Interfaces
  */
  network_interface {
    # ID of the network interface to attach (Required)
    network_interface_id = aws_network_interface.eni[each.key].id

    # Whether or not to delete the network interface on instance
    # termination. Defaults to false
    delete_on_termination = null

    # (Required) Integer index of the network interface attachment
    device_index = local.eth_index_default
  }

  # Root Block Device
  root_block_device {
    volume_type = each.value.volume_type # Default "gp2"
    volume_size = each.value.volume_size
    encrypted   = each.value.encrypted
  }

  # If true, enables EC2 Instance Stop Protection
  # lookup(local.configuration_data[each.key], "stop_protection", null)
  disable_api_stop = each.value.stop_protection

  # If true, enables EC2 Instance Termination Protection
  # lookup(local.configuration_data[each.key], "termination_protection", null)
  disable_api_termination = each.value.termination_protection

  maintenance_options {
    auto_recovery = "default"
  }

  /*
    Hibernation
    If true, the launched EC2 instance will support hibernation
    For hibernation, the root device volume must be encrypted
  */
  hibernation = lookup(
    local.configuration_data[each.key], "encrypted", null
  ) == true ? true : false

  # Shutdown behavior for the instance
  instance_initiated_shutdown_behavior = "stop"

  # If true, the launched EC2 instance will have detailed monitoring enabled
  monitoring = true

  # Private DNS Options
  private_dns_name_options {
    enable_resource_name_dns_a_record = true
    enable_resource_name_dns_aaaa_record = (
      var.enable_ipv6 && !contains(local.no_ipv6_instance_types, var.ec2_instance_type)
    ) ? true : false

    # Type of hostname for Amazon EC2 instances
    hostname_type = "ip-name"
  }

  # Reference to `ssh` public key (from `ssh_keygen_module`)
  key_name = each.value.os == "linux" ? var.ssh_key_pair_name : null

  credit_specification {
    # Credit option for CPU usage "standard" or "unlimited"
    cpu_credits = can(regex("^([tT][23][a]*?)\\.[[:ascii:]]*$", var.ec2_instance_type)) ? "standard" : null
  }


  /*
    Set of disabled options due to resource `aws_network_interface`
    usage

  availability_zone = ""              # AZ to start the instance in
  associate_public_ip_address = true  # Whether to associate a public IP address
                                      # with an instance in a VPC

  # VPC Subnet ID to launch in
  subnet_id = ""

  # Associate private ips with an instance
  private_ip = ""                     # Private IP address to associate with
                                      # the instance in a VPC
  secondary_private_ips = []          # List of secondary private IPv4 addresses
                                      # to assign to the instance's primary NIC
  */

  tags = merge(
    {
      # Regex (extracting hostname)
      # ${regexall("(^[0-9A-Za-z-]+[^\\.])\\.*", lookup(
      #   aws_network_interface.eni[each.key], "private_dns_name"
      # ))[0]}
      #
      Name = "${split(".", lookup(
        aws_network_interface.eni[each.key], "private_dns_name"
        ))[0]
        }-%{if each.value.os == "linux"}lnx%{else}win%{endif}${
        random_string.confg_id.keepers.random_index
        }${
        each.key
      }-${random_string.confg_id.result}"
      Resource = "i"
      FullName = "${split(".", lookup(
        aws_network_interface.eni[each.key], "private_dns_name"
        ))[0]
        }-%{if each.value.os == "linux"}lnx%{else}win%{endif}${
        random_string.confg_id.keepers.random_index
        }${
        each.key
        }-${
        random_string.confg_id.result
      }.i${var.domain}"
      Tier     = each.value.tier
      OSFamily = each.value.os
    },
    var.all_tags
  )


  lifecycle {
    precondition {
      # At least one network interface (or set) must be created and
      # required number of network interfaces created
      condition = (
        length(aws_network_interface.eni) > 0 &&
        length(aws_network_interface.eni) == local.main_count
      )
      error_message = <<-ERR
        Error! At least one `public` or `private` network interface must be
        created or not all necessary network interfaces have been created
      ERR
    }
  }

  depends_on = [
    null_resource.check_config_parameters,
    local.configuration_data,
    aws_network_interface.eni,
  ]
}

/*
  //
    Optional to instance `network_interface` block
  //

resource "aws_network_interface_attachment" "eni_to_instance" {
  # Attach an eni resource to EC2 instance
  count = length(aws_network_interface.eni)

  instance_id          = aws_instance.ec2[count.index].id
  network_interface_id = aws_network_interface.eni[count.index].id
  device_index         = 0

  depends_on = [
    aws_network_interface.eni,
    aws_instance.ec2,
  ]
}
*/


/*
  Output inventory file build
*/
locals {
  ip_prefix = " ansible_host="
}

resource "local_file" "inventory" {
  count           = var.ec2_inventory_file ? 1 : 0
  filename        = "${path.root}/inventory-${random_string.confg_id.result}.ini"
  file_permission = "0644"

  depends_on = [
    aws_instance.ec2,
    random_string.confg_id,
  ]

  /*
    Inventory file content
  */
  content = <<EOF
[all_public:children]
linux_public
windows_public

[linux_public]
%{~for ec2 in [
  for ec2 in values(aws_instance.ec2) : ec2 if(
    ec2.tags["OSFamily"] == "linux" &&
    ec2.tags["Tier"] == "public"
  )
]
}
${trimspace(
  ec2.public_dns
)
}${local.ip_prefix}${trimspace(
  ec2.public_ip
  )}
%{~endfor}

[windows_public]
%{~for ec2 in [
  for ec2 in values(aws_instance.ec2) : ec2 if(
    ec2.tags["OSFamily"] == "windows" &&
    ec2.tags["Tier"] == "public"
  )
]
}
${trimspace(
  ec2.public_dns
)
}${local.ip_prefix}${trimspace(
  ec2.public_ip
  )}
%{~endfor}

[all_private:children]
linux_external
linux_internal
windows_external
windows_internal

[linux_external]
%{~for ec2 in [
  for ec2 in values(aws_instance.ec2) : ec2 if(
    ec2.tags["OSFamily"] == "linux" &&
    ec2.tags["Tier"] == "public"
  )
]
}
${trimspace(
  ec2.private_dns
)
}${local.ip_prefix}${trimspace(
  ec2.private_ip
  )}
%{~endfor}

[linux_internal]
%{~for ec2 in [
  for ec2 in values(aws_instance.ec2) : ec2 if(
    ec2.tags["OSFamily"] == "linux" &&
    ec2.tags["Tier"] == "private"
  )
]
}
${trimspace(
  ec2.private_dns
)
}${local.ip_prefix}${trimspace(
  ec2.private_ip
  )}
%{~endfor}

[windows_external]
%{~for ec2 in [
  for ec2 in values(aws_instance.ec2) : ec2 if(
    ec2.tags["OSFamily"] == "windows" &&
    ec2.tags["Tier"] == "public"
  )
]
}
${trimspace(
  ec2.private_dns
)
}${local.ip_prefix}${trimspace(
  ec2.private_ip
  )}
%{~endfor}

[windows_internal]
%{~for ec2 in [
  for ec2 in values(aws_instance.ec2) : ec2 if(
    ec2.tags["OSFamily"] == "windows" &&
    ec2.tags["Tier"] == "private"
  )
]
}
${trimspace(
  ec2.private_dns
)
}${local.ip_prefix}${trimspace(
  ec2.private_ip
)}
%{~endfor}
EOF
}
