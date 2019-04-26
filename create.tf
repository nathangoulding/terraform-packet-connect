locals {
  # ssh keyfile
  ssh_key = "${file("/home/user/.ssh/privkey")}"
  # the IP and subnet you wish to announce to azure
  bgp_ip = "10.99.99.1"
  bgp_netmask = "255.255.255.255"
  bgp_cidr = "32"

  # EXPRESSROUTE SETTINGS
  # needs to match a facility where Packet has deployed Packet Connect
  facility = "ewr1"
  # this needs to match the expressroute key in azure's portal
  expressroute_key = "CHANGEME"
  # this needs to match the expressroute port speed
  port_speed = 100
  # from azure portal under expressroute circuit private peering
  # the BGP neighbor IP on azure side is the second IP from the /30 primary subnet
  # in this example, 172.16.0.0/3 is the primary subnet
  neighbor_ip = "172.16.0.2"
  # azure peers with you on the first IP from the /30 primary subnet, which gets bound
  # to the interface attached to the VLAN; BGP is not necessary to be enabled in Packet
  local_ip = "172.16.0.1"
  # this needs to match the Peer ASN from the private peering setup
  local_as = "65501"
  # azure always uses 12076
  remote_as = "12076"
}

provider "packet" {
  version = ">= 2.0.0"
}

resource "packet_project" "project1" {
  name = "Packet Connect"
}

resource "packet_device" "device1" {
  hostname         = "test-azure"
  plan             = "m1.xlarge.x86"
  facilities       = ["${local.facility}"]
  operating_system = "ubuntu_18_04"
  project_id       = "${packet_project.project1.id}"
  billing_cycle    = "hourly"
  network_type     = "hybrid"
}

resource "packet_vlan" "vlan1" {
  description = "Packet Connect VLAN"
  facility    = "${local.facility}"
  project_id  = "${packet_project.project1.id}"
}

resource "packet_connect" "my_expressroute" {
  name = "test-azure"
  facility = "${local.facility}"
  project_id = "${packet_project.project1.id}"
  # provider ID for Azure ExpressRoute is ed5de8e0-77a9-4d3b-9de0-65281d3aa831
  provider_id = "ed5de8e0-77a9-4d3b-9de0-65281d3aa831"
  # provider_payload for Azure ExpressRoute provider is your ExpressRoute
  # authorization key (in UUID format)
  provider_payload = "${local.expressroute_key}"
  port_speed = "${local.port_speed}"
  vxlan = "${packet_vlan.vlan1.vxlan}"
}

resource "packet_port_vlan_attachment" "vlan_assignment" {
  device_id = "${packet_device.device1.id}"
  port_name = "eth1"
  vlan_vnid = "${packet_vlan.vlan1.vxlan}"
}

data "external" "find_second_iface" {
  program = ["bash", "${path.root}/find_second_iface.sh"]

  query = {
    host    = "${packet_device.device1.access_public_ipv4}"
    ssh_key = "${local.ssh_key}"
  }
}

data "template_file" "interface_lo0" {
  template = <<EOF
auto lo:0
iface lo:0 inet static
   address $${bgp_ip}
   netmask $${bgp_netmask}
EOF

  vars = {
    bgp_ip      = "${local.bgp_ip}"
    bgp_netmask = "${local.bgp_netmask}"
  }
}

data "template_file" "interface_second" {
  template = <<EOF
auto $${iface}
iface $${iface} inet static
   address $${local_ip}
   netmask 255.255.255.252
EOF

  vars = {
    local_ip = "${local.local_ip}"
    iface    = "${data.external.find_second_iface.result["iface"]}"
  }
}

data "template_file" "bird_conf_template" {

  template = <<EOF
filter packet_bgp {
    if net = $${bgp_ip}/$${bgp_cidr} then accept;
}
router id $${local_ip};
protocol direct {
    interface "lo";
}
protocol kernel {
    scan time 10;
    persist;
    import all;
    export all;
}
protocol device {
    scan time 10;
}
protocol bgp {
    export filter packet_bgp;
    local as $${local_as};
    neighbor $${neighbor_ip} as $${remote_as};
}
EOF

  vars = {
    bgp_ip      = "${local.bgp_ip}"
    bgp_cidr    = "${local.bgp_cidr}"
    local_ip    = "${local.local_ip}"
    local_as    = "${local.local_as}"
    neighbor_ip = "${local.neighbor_ip}"
    remote_as   = "${local.remote_as}"
  }
}

resource "null_resource" "configure_bird" {

  connection {
    type = "ssh"
    host = "${packet_device.device1.access_public_ipv4}"
    private_key = "${local.ssh_key}"
    agent = false
  }

  provisioner "remote-exec" {
    inline = [
      "apt-get install bird",
      "mv /etc/bird/bird.conf /etc/bird/bird.conf.old",
      "cp /etc/network/interfaces /etc/network/interfaces.bak",
      "awk -v n=5 'NR>n{print line[NR%n]};{line[NR%n]=$0}' /etc/network/interfaces.bak > /etc/network/interfaces",
    ]
  }

  triggers = {
    template = "${data.template_file.bird_conf_template.rendered}"
    template = "${data.template_file.interface_lo0.rendered}"
    template = "${data.template_file.interface_second.rendered}"
  }

  provisioner "file" {
    content     = "${data.template_file.bird_conf_template.rendered}"
    destination = "/etc/bird/bird.conf"
  }

  provisioner "file" {
    content     = "${data.template_file.interface_lo0.rendered}"
    destination = "/etc/network/interfaces.d/lo0"
  }

  provisioner "file" {
    content     = "${data.template_file.interface_second.rendered}"
    destination = "/etc/network/interfaces.d/second"
  }

  provisioner "remote-exec" {
    inline = [
      "sed -i -E 's/bond-slaves (.*) (.*)/bond-slaves \\1/' /etc/network/interfaces",
      "grep /etc/network/interfaces.d /etc/network/interfaces || echo 'source /etc/network/interfaces.d/*' >> /etc/network/interfaces",
      "ifup lo:0",
      "ifdown ${data.external.find_second_iface.result["iface"]}",
      "ifup ${data.external.find_second_iface.result["iface"]}",
      "service bird restart",
    ]
  }
}
