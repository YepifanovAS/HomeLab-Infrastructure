locals {
  proxmox_ve_config = yamldecode(file("${var.config_dir}/proxmox_ve.yaml"))
  instance_types_raw = yamldecode(file("${var.config_dir}/instance_types.yaml"))
  vm_config_raw = yamldecode(file("${var.config_dir}/vm_config.yaml"))
  import_disks_config = local.vm_config_raw.import_disks
  single_nodes = local.vm_config_raw.single
  multiple_nodes_raw = flatten([
    for nodegroup in local.vm_config_raw.multiples : [
      for i in range( nodegroup.count.vmcount ) : merge(nodegroup, {
        name = format(
          "%s%s%0${nodegroup.naming.digits}d",
          nodegroup.naming.name_base,
          try(nodegroup.naming.delimiter,"-"),
          nodegroup.count.startfrom + i
        )
        networks = {
          for netname, net in nodegroup.networks : netname => {
            gateway = try(net.gateway, null)
            ip = "${cidrhost(net.subnet, net.ip_start + i)}/${split("/", net.subnet)[1]}"
          }
        }
        vm = merge(nodegroup.vm, { vmid = nodegroup.vm.vmid_start + i} )
      })
    ]
  ])
  multiple_nodes = { for node in local.multiple_nodes_raw : node.name => node }
  # порядок поєднання свідомо обраний. Якщо ідентифікатори вузлів в multiple_nodes
  #   та single_nodes сбігаються, краще залишити той, що в single_nodes
  nodes = merge(local.multiple_nodes,local.single_nodes)
}


resource "proxmox_download_file" "diskimport_cloudimage_file" {
  for_each = {
    for disk in local.import_disks_config : disk.name => disk
  }
  content_type = "import"
  datastore_id = local.proxmox_ve_config.proxmox_ve_imagestorage
  node_name    = local.proxmox_ve_config.proxmox_ve_hosts[0]
  url          = each.value.import_url
  # need to rename the file to *.qcow2 to indicate the actual file format for import
  file_name = "terraform_${split(".", basename(each.value.import_url))[0]}.qcow2"
}

resource "proxmox_virtual_environment_vm" "vm" {
  for_each = local.nodes

  name = each.value.name
  node_name = local.proxmox_ve_config.proxmox_ve_hosts[0]
  vm_id = each.value.vm.vmid

  tags = concat(
      ["terraform"],
      each.value.vm.tags
    )

  machine     = "q35"
  bios        = "ovmf"

  boot_order = ["scsi0"]

  memory {
      dedicated = local.instance_types_raw.vm[split(".",each.value.vm.instance_type)[0]][split(".",each.value.vm.instance_type)[1]].memory
  }
  cpu {
    cores = local.instance_types_raw.vm[split(".",each.value.vm.instance_type)[0]][split(".",each.value.vm.instance_type)[1]].cpu
    type = "host"
  }

  dynamic "network_device" {
    for_each = each.value.vm.interfaces
    content {
      bridge = network_device.value
    }
  }

  efi_disk {
    datastore_id = local.proxmox_ve_config.proxmox_ve_datastorage
    type         = "4m"
    pre_enrolled_keys = true
  }
  scsi_hardware = "virtio-scsi-single"

  disk {
    interface = "scsi0"
    datastore_id = local.proxmox_ve_config.proxmox_ve_datastorage
    size = (each.value.vm.disk_size > local.instance_types_raw.vm[split(".",each.value.vm.instance_type)[0]].default.size_minimum) ? each.value.vm.disk_size : local.instance_types_raw.vm[split(".",each.value.vm.instance_type)[0]].default.size_minimum
    import_from = proxmox_download_file.diskimport_cloudimage_file[local.instance_types_raw.vm[split(".",each.value.vm.instance_type)[0]].default.import_disk].id
  }

  dynamic "disk" {
    for_each = {
      for i,disk in each.value.vm.additional_disks : i=>disk
    }
    content {
      interface = "scsi${disk.key+1}"
      size = disk.value.size
      datastore_id = local.proxmox_ve_config.proxmox_ve_datastorage
    }
  }

  serial_device {
    device = "socket"
  }

  vga {
    type = "serial0"
  }

  initialization {
    datastore_id = local.proxmox_ve_config.proxmox_ve_datastorage
    dns {
      servers = flatten([each.value.dns.servers])
      domain = each.value.dns.domain
    }
    upgrade = true
    dynamic "ip_config" {
      for_each = each.value.networks
      content {
        ipv4 {
            address = ip_config.value.ip
            gateway = try(ip_config.value.gateway, null)
          }
      }
    }
    user_account {
        username = each.value.user.name
        keys = flatten([each.value.user.ssh_keys])
    }
  }
}

resource "proxmox_pool_membership" "singlevm_pool_membership" {
  for_each = local.nodes

  pool_id = try(each.value.vm.pool,"unidentified")
  vm_id   = proxmox_virtual_environment_vm.vm[each.key].id
}
