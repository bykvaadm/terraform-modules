data "vsphere_datacenter" "dc" {
  name = var.vsphere_datacenter_name
}

data "vsphere_tag_category" "Environment" {
  name = "Environment"
}

data "vsphere_tag" "Environment" {
  name        = "PROD"
  category_id = data.vsphere_tag_category.Environment.id
}

data "vsphere_tag_category" "CostCenter" {
  name = "CostCenter"
}

data "vsphere_tag" "CostCenter" {
  name        = "MSS"
  category_id = data.vsphere_tag_category.CostCenter.id
}

data "vsphere_tag_category" "CostCenterCode" {
  name = "CostCenterCode"
}

data "vsphere_tag" "CostCenterCode" {
  name        = "3-3"
  category_id = data.vsphere_tag_category.CostCenterCode.id
}

data "vsphere_datastore" "datastore" {
  name          = var.vsphere_datastore_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_resource_pool" "pool" {
  name          = var.vsphere_resource_pool_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  count         = length(var.vsphere_network_name)
  name          = element(var.vsphere_network_name, count.index)
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = var.vsphere_virtual_machine_template_name
  datacenter_id = data.vsphere_datacenter.dc.id
  count         = var.vsphere_virtual_machine_template_name == "" ? 0 : 1
}

resource "vsphere_tag" "tag" {
  name        = var.name
  category_id = var.category
  description = "Managed by Terraform"
}

resource "vsphere_tag" "uniq_id_tag" {
  name        = "${var.uniq_id_tag_name}_${count.index + 1}"
  category_id = var.category
  description = "Managed by Terraform"
  count       = var.uniq_id_tag_count
}

locals {
  tags = concat(vsphere_tag.tag.*.id,
  var.vsphere_tag_id,
  list(data.vsphere_tag.Environment.id),
  list(data.vsphere_tag.CostCenter.id),
  list(data.vsphere_tag.CostCenterCode.id))
}

resource "vsphere_virtual_machine" "vm" {
  name             = "${var.prefix}${var.name}-${count.index}"
  count            = var.with_vm_clone == true ? var.instance_count : 0
  tags             = var.uniq_id_tag_count != 0 ? concat(local.tags, list(element(vsphere_tag.uniq_id_tag, count.index).id)) : local.tags
  resource_pool_id = data.vsphere_resource_pool.pool.id
  datastore_id     = data.vsphere_datastore.datastore.id
  enable_disk_uuid = "true"

  num_cpus               = var.num_cpus
  cpu_hot_add_enabled    = true
  memory_hot_add_enabled = true
  memory_reservation     = var.memory
  memory                 = var.memory

  guest_id = var.guest_id

  folder = var.vsphere_vm_folder

  lifecycle {
    ignore_changes = [
      clone[0].customize]
  }

  dynamic "network_interface" {
    for_each = [for n in data.vsphere_network.network: {
      id = n.id
    }]
    content {
      network_id = network_interface.value.id
    }
  }

  dynamic "disk" {
    for_each = [for d in var.disk_size: {
      size   = d.size
      number = d.number
    }]

    content {
      label            = format("disk%s", disk.value.number)
      size             = disk.value.size
      thin_provisioned = data.vsphere_virtual_machine.template.0.disks[0].thin_provisioned
      eagerly_scrub    = data.vsphere_virtual_machine.template.0.disks[0].eagerly_scrub
      unit_number      = disk.value.number
    }
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.0.id

    customize {
      linux_options {
        host_name = "${var.prefix}${var.name}-${count.index}"
        domain    = "soc.bi.zone"
      }
      dynamic "network_interface" {
        for_each = [for n in var.network_address: {
          ip = n[count.index]
        }]
        content {
          ipv4_address = network_interface.value.ip
          ipv4_netmask = var.ipv4_netmask
        }
      }

      ipv4_gateway    = var.ipv4_gateway
      dns_server_list = var.dns_server_list
    }
  }
}

resource "vsphere_virtual_machine" "blank_vm" {
  name                        = "${var.prefix}${var.name}-${count.index}"
  count                       = var.with_vm_clone == true ? 0 : var.instance_count
  tags                        = var.uniq_id_tag_count != 0 ? concat(local.tags, list(element(vsphere_tag.uniq_id_tag, count.index).id)) : local.tags
  resource_pool_id            = data.vsphere_resource_pool.pool.id
  datastore_id                = data.vsphere_datastore.datastore.id
  enable_disk_uuid            = "true"
  wait_for_guest_ip_timeout   = 0
  wait_for_guest_net_routable = false
  wait_for_guest_net_timeout  = 0

  num_cpus               = var.num_cpus
  cpu_hot_add_enabled    = true
  memory_hot_add_enabled = true
  memory_reservation     = var.memory
  memory                 = var.memory

  guest_id = var.guest_id
  folder   = var.vsphere_vm_folder


  cdrom {
    client_device = true
  }

  dynamic "network_interface" {
    for_each = [for n in data.vsphere_network.network: {
      id = n.id
    }]
    content {
      network_id = network_interface.value.id
    }
  }

  scsi_type = var.scsi_type

  dynamic "disk" {
    for_each = [for d in var.disk_size: {
      size   = d.size
      number = d.number
    }]

    content {
      label            = format("disk%s", disk.value.number)
      size             = disk.value.size
      thin_provisioned = true
      eagerly_scrub    = false
      unit_number      = disk.value.number
    }
  }
}