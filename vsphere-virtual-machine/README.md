# Example usage

```
module "test-vm" {
  source = "git::https://git@github.com:bykvaadm/terraform-modules.git//vsphere-virtual-machine?ref=v1.0.10"

  vsphere_datacenter_name    = "string, put vsphere datacenter here"
  vsphere_datastore_name     = "string, put vsphere datastore here (where should vm disks stored)"
  vsphere_resource_pool_name = "string, put resource pool here"
  vsphere_network_name       = "list, put network names here"
  guest_id                   = "string, put guest id (VirtualMachineGuestOsIdentifier)"
  category                   = "category id (tags & custom attributes)"
  vsphere_tag_id             = "id of additional tags, created earlier, will be assigned to all vms"

  name   = "test-vm"
  prefix = "string, can be null. used as vm name prefix (ie dc-msk-)"
  groups = "string, used to create tags, which will be assigned to all vms"

  num_cpus  = "number, count of cpu"
  memory    = "number, amount of memory, i.e. 8*1024"
  disk_size = "list, put here disk sizes"

  instance_count    = "number, count of vms, will be created with name-0, name-1, ..."
  with_vm_clone     = "bool, clone vm or create blank vm without cloning"
  vsphere_vm_folder = "string, folder in esxi where to store vm"
  network_address   = "list of lists. each list for vm interfaces"
  ipv4_netmask      = "number, cidr netmask"
  ipv4_gateway      = "string, gateway"
  dns_server_list   = "list, dns servers"

  vsphere_virtual_machine_template_name = "string, name of template to copy vm from"
}
```

## more about tags.

imagine u have ceph cluster. this cluster consists of vms with osd and mon role.
with ansible u may want to have ability to have 3 roles: 
- one for all ceph servers
- one for osd servers
- one for mon servers
with tags, assigned to vms u can do it - 
simple run ansible dynamic inventory and it will read tags from vms
and then group them.
So, with vsphere_tag_id u can tell module about tag created earlier,
in this case simple create tag ceph before module test-vm
with groups u tell module to create module-specific tags - 
u create 2 copies of module, tell it groups and vm count and u will get necessary tags.

as a result u will get servers:
- ceph-mon-0 with tags: ceph, mon
- ceph-mon-1 with tags: ceph, mon
- ceph-mon-2 with tags: ceph, mon
- ceph-osd-0 with tags: ceph, osd
- ceph-osd-1 with tags: ceph, osd
- ceph-osd-2 with tags: ceph, osd
