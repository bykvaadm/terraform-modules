data "vsphere_datacenter" "dc" {
  name = var.vsphere_datacenter_name
}

data "vsphere_tag_category" "Environment" {
  name = "Environment"
}

data "vsphere_tag" "Environment" {
  name        = var.environment
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
  count         = length(var.datastore_name)
  name          = element(var.datastore_name, count.index)
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

resource "kubernetes_endpoints" "prometheus" {
  count = length(var.prometheus) == 0 ? 0 : var.instance_count
  metadata {
    namespace = "headless"
    name      = "${var.prefix}${var.name}-${count.index}"
  }

  subset {
    address {
      ip = var.network_address[0][count.index]
    }
    dynamic "port" {
      for_each = [for s in var.prometheus: {
        name     = s.name
        port     = s.port
        protocol = s.protocol
      }]
      content {
        name     = port.value.name
        port     = port.value.port
        protocol = port.value.protocol
      }
    }
  }
}

resource "kubernetes_service" "prometheus" {
  count = length(var.prometheus) == 0 ? 0 : var.instance_count
  metadata {
    namespace   = "headless"
    name        = "${var.prefix}${var.name}-${count.index}"
    labels      = {
      service = var.name
    }
    annotations = {
      "prometheus.io/scrape" = "true"
    }
  }
  spec {
    cluster_ip = "None"
    type       = "ClusterIP"
  }
}


resource "vsphere_virtual_machine" "vm" {
  name             = "${var.prefix}${var.name}-${count.index}"
  count            = var.with_vm_clone == true && var.operation_system == "linux" ? var.instance_count : 0
  tags             = var.uniq_id_tag_count != 0 ? concat(local.tags, list(element(vsphere_tag.uniq_id_tag, count.index).id)) : local.tags
  resource_pool_id = data.vsphere_resource_pool.pool.id
  datastore_id     = element(data.vsphere_datastore.datastore.*.id, count.index)
  enable_disk_uuid = "true"
  firmware         = var.firmware
  nested_hv_enabled = var.nested_hv_enabled

  num_cpus               = var.num_cpus
  cpu_hot_add_enabled    = true
  memory_hot_add_enabled = true
  memory_reservation     = var.memory_reservation != 0 ? var.memory_reservation : var.memory / 2
  memory                 = var.memory

  guest_id = var.guest_id

  folder = var.vsphere_vm_folder

  lifecycle {
    ignore_changes = [
      clone[0].customize,
      custom_attributes]
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
      size             = d.size
      number           = d.number
      eagerly_scrub    = d.eagerly_scrub
      thin_provisioned = d.thin_provisioned
    }]

    content {
      label            = format("disk%s", disk.value.number)
      size             = disk.value.size
      thin_provisioned = disk.value.thin_provisioned
      eagerly_scrub    = disk.value.eagerly_scrub
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

resource "vsphere_virtual_machine" "windows_vm" {
  name             = "${var.prefix}${var.name}-${count.index}"
  count            = var.with_vm_clone == true && var.operation_system == "windows" ? var.instance_count : 0
  tags             = var.uniq_id_tag_count != 0 ? concat(local.tags, list(element(vsphere_tag.uniq_id_tag, count.index).id)) : local.tags
  resource_pool_id = data.vsphere_resource_pool.pool.id
  datastore_id     = element(data.vsphere_datastore.datastore.*.id, count.index)
  enable_disk_uuid = "true"
  firmware         = var.firmware
  nested_hv_enabled = var.nested_hv_enabled


  num_cpus               = var.num_cpus
  cpu_hot_add_enabled    = true
  memory_hot_add_enabled = true
  memory_reservation     = var.memory / 2
  memory                 = var.memory

  guest_id = var.guest_id

  folder = var.vsphere_vm_folder

  lifecycle {
    ignore_changes = [
      clone[0].customize,
      custom_attributes]
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
      size             = d.size
      number           = d.number
      eagerly_scrub    = d.eagerly_scrub
      thin_provisioned = d.thin_provisioned
    }]

    content {
      label            = format("disk%s", disk.value.number)
      size             = disk.value.size
      thin_provisioned = disk.value.thin_provisioned
      eagerly_scrub    = disk.value.eagerly_scrub
      unit_number      = disk.value.number
    }
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.0.id

    customize {
      windows_options {
        computer_name = "${var.prefix}${var.name}-${count.index}"
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
  datastore_id                = element(data.vsphere_datastore.datastore.*.id, count.index)
  enable_disk_uuid            = "true"
  wait_for_guest_ip_timeout   = 0
  wait_for_guest_net_routable = false
  wait_for_guest_net_timeout  = 0
  nested_hv_enabled = var.nested_hv_enabled
  firmware         = var.firmware

  num_cpus               = var.num_cpus
  cpu_hot_add_enabled    = true
  memory_hot_add_enabled = true
  memory_reservation     = var.memory / 2
  memory                 = var.memory

  guest_id = var.guest_id
  folder   = var.vsphere_vm_folder

  lifecycle {
    ignore_changes = [
      custom_attributes]
  }

  cdrom {
    client_device = var.cdrom_datastore_id == "" ? true : false
    datastore_id  = var.cdrom_datastore_id
    path          = var.cdrom_iso_path
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
      size             = d.size
      number           = d.number
      eagerly_scrub    = d.eagerly_scrub
      thin_provisioned = d.thin_provisioned
    }]

    content {
      label            = format("disk%s", disk.value.number)
      size             = disk.value.size
      thin_provisioned = disk.value.thin_provisioned
      eagerly_scrub    = disk.value.eagerly_scrub
      unit_number      = disk.value.number
    }
  }
}
