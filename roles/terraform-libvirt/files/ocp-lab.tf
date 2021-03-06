# instance the provider
provider "libvirt" {
  uri = "qemu:///system"
}


# We fetch the latest ubuntu release image from their mirrors

resource "libvirt_volume" "os_image" {
  name = "${var.base_image}"
  source = "${var.qcow2_image}"
}

resource "libvirt_volume" "ocp-bastion-qcow2" {
  name = "ocp-bastion-qcow2"
  base_volume_id = "${libvirt_volume.os_image.id}"
}

resource "libvirt_volume" "ocp-master-qcow2" {
  name = "ocp-master-qcow2-${count.index+1}"
  base_volume_id = "${libvirt_volume.os_image.id}"
  count = "${var.master_count}"
}
resource "libvirt_volume" "ocp-master-docker-qcow2" {
  name = "ocp-master-docker-qcow2-${count.index+1}"
  size = "${var.master_docker_device}"
  count = "${var.master_count}"
}

resource "libvirt_volume" "ocp-node-qcow2" {
  name = "ocp-node-qcow2-${count.index+1}"
  base_volume_id = "${libvirt_volume.os_image.id}"
  count = "${var.nodes_count}"
}
resource "libvirt_volume" "ocp-node-docker-qcow2" {
  name = "ocp-node-docker-qcow2-${count.index+1}"
  size = "${var.nodes_docker_device}"
  count = "${var.nodes_count}"
}

data "template_file" "user_data" {
  template = "${file("${path.module}/cloud_init.cfg")}"
}

data "template_file" "network_config" {
  template = "${file("${path.module}/network_config.cfg")}"
}

# for more info about paramater check this out
# https://github.com/dmacvicar/terraform-provider-libvirt/blob/master/website/docs/r/cloudinit.html.markdown
# Use CloudInit to add our ssh-key to the instance
# you can add also meta_data field
resource "libvirt_cloudinit_disk" "commoninit" {
  name           = "commoninit.iso"
  user_data      = "${data.template_file.user_data.rendered}"
  network_config = "${data.template_file.network_config.rendered}"
}


# Create the machines
resource "libvirt_domain" "ocp-master" {
  count = "${var.master_count}"
  name   = "ocp-master-${count.index+1}"
  memory = "${var.master_memory}"
  vcpu   = "${var.master_cpu}"

  cpu = {
    mode = "host-passthrough"
  }


  cloudinit = "${libvirt_cloudinit_disk.commoninit.id}"
  cpu = {
    mode = "host-passthrough"
  }

  network_interface {
    network_name = "ocp-net"
    hostname       = "ocp-master-${count.index+1}"
    addresses      = ["10.10.10.2${count.index+1}"]
    mac            = "AA:BB:CC:11:22:2${count.index+1}"
    wait_for_lease = true
  }
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }
  disk {
    volume_id = "${libvirt_volume.ocp-master-qcow2.*.id[count.index]}"
  }
  disk {
    volume_id = "${libvirt_volume.ocp-master-docker-qcow2.*.id[count.index]}"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

resource "libvirt_domain" "ocp-node" {
  count = "${var.nodes_count}"
  name   = "ocp-node-${count.index+1}"
  memory = "${var.nodes_memory}"
  vcpu   = "${var.nodes_cpu}"

  cpu = {
    mode = "host-passthrough"
  }

  cloudinit = "${libvirt_cloudinit_disk.commoninit.id}"
  cpu = {
    mode = "host-passthrough"
  }

  network_interface {
    network_name = "ocp-net"
    hostname       = "ocp-node-${count.index+1}"
    addresses      = ["10.10.10.4${count.index+1}"]
    mac            = "AA:BB:CC:11:22:4${count.index+1}"
    wait_for_lease = true
  }
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }
  disk {
    volume_id = "${libvirt_volume.ocp-node-qcow2.*.id[count.index]}"
  }
  disk {
    volume_id = "${libvirt_volume.ocp-node-docker-qcow2.*.id[count.index]}"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

resource "libvirt_domain" "ocp-bastion" {
  name   = "ocp-bastion"
  memory = "2048"
  vcpu   = 1

  cloudinit = "${libvirt_cloudinit_disk.commoninit.id}"

  network_interface {
    network_name = "ocp-net"
    hostname       = "ocp-bastion"
    addresses      = ["10.10.10.10"]
    mac            = "AA:BB:CC:11:22:10"
    wait_for_lease = true
  }
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }
  disk {
    volume_id = "${libvirt_volume.ocp-bastion-qcow2.id}"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}
# IPs: use wait_for_lease true or after creation use terraform refresh and terraform show for the ips of domain

