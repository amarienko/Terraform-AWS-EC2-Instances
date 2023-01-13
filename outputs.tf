/*
  Default AMIs data
*/
output "ec2__00__images_linux" {
  value = (
    local.platform_linux && length(
      data.aws_ami.linux
      ) > 0 && try(
      data.aws_ami.linux["default"] != null
    )
    ) ? {
    for dist, info in data.aws_ami.linux : info.id => {
      "Default Image"     = dist == "default" ? "Yes" : "No",
      "Image Description" = info.description,
      "OS/Platform"       = info.platform_details,
      "OS Architecture"   = info.architecture,
      "Creation Date"     = info.creation_date,
      "Image Owner"       = info.owner_id
    } if dist == "default" # filters only default values
  } : null
}

output "ec2__00__images_windows" {
  value = (
    local.platform_windows && length(
      data.aws_ami.windows
      ) > 0 && try(
      data.aws_ami.windows["default"] != null
    )) ? {
    for dist, info in data.aws_ami.windows : info.id => {
      "Default Image"     = dist == "default" ? "Yes" : "No",
      "Image Description" = info.description,
      "OS/Platform"       = info.platform_details,
      "OS Architecture"   = info.architecture,
      "Creation Date"     = info.creation_date,
      "Image Owner"       = info.owner_id
    } if dist == "default"
  } : null
}


/*
  Network Interfaces
*/
output "ec2__01__network_interfaces" {
  value = sum([for v in var.ec2_config_parameters : v.qty]) > 0 ? {
    for eni in aws_network_interface.eni : eni.id => {
      "MAC Address"      = eni.mac_address
      "Security Groups"  = eni.security_groups
      "Subnet ID"        = eni.subnet_id
      "Private Hostname" = eni.private_dns_name
      "Privete IP(s)"    = eni.private_ips
      "IPv6 Addresses"   = eni.ipv6_addresses
    }
  } : null
}

/*
  Instance(s) details
*/
output "ec2__02__instances" {
  value = length(aws_instance.ec2) > 0 ? {
    for ec2 in aws_instance.ec2 : ec2.id => {
      "Instance ARN"      = ec2.arn,
      "Instance Type"     = ec2.instance_type,
      "Availability Zone" = ec2.availability_zone,
      "Subnet ID"         = ec2.subnet_id,
      "Main NIC ID"       = ec2.primary_network_interface_id,
      "Public Hostname"   = ec2.public_dns,
      "Public IP"         = ec2.public_ip,
      "Private Hostname"  = ec2.private_dns,
      "Private IP"        = ec2.private_ip,
      "IPv6 Address"      = ec2.ipv6_addresses
    }
  } : null
}

/*
  Inventory File
*/
output "ec2__03__inventory" {
  value = var.ec2_inventory_file ? {
    "Inventory File ID"  = local_file.inventory[0].id
    "Inventory FileName" = local_file.inventory[0].filename
  } : null
}
