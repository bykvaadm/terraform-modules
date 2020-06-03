variable "vsphere_datacenter_name" {}

variable "datastore_name" {}

variable "vsphere_resource_pool_name" {}

variable "vsphere_network_name" {
  type    = list
  default = []
}

variable "vsphere_virtual_machine_template_name" {
  default = ""
}

variable "guest_id" {}

variable "name" {}

variable "num_cpus" {}

variable "memory" {}

variable "memory_reservation" {
  type = number
  default = 0
}

variable "disk_size" {
  type    = list
  default = []
}

variable "instance_count" {
  default = 1
}

variable "category" {}

variable "vsphere_tag_id" {
  type    = list
  default = []
}

variable "prefix" {
  default = ""
}

variable "network_address" {
  type    = list
  default = []
}

variable "vsphere_vm_folder" {}

variable "uniq_id_tag_count" {
  default = 0
}

variable "uniq_id_tag_name" {
  default = ""
}

variable "with_vm_clone" {
  default = true
}

variable "ipv4_gateway" {
  default = ""
}

variable "ipv4_netmask" {
  default = ""
}

variable "dns_server_list" {
  type    = list
  default = []
}

variable "scsi_type" {
  default = "pvscsi"
}

variable "cdrom_datastore_id" {
  default = ""
}
variable "cdrom_iso_path" {
  default = ""
}
variable "environment" {}

variable "operation_system" {
  default = "linux"
}

variable "firmware" {
  default = "bios"
}

variable "prometheus" {
  type = list
  default = []
}
