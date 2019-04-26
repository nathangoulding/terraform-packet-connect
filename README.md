# Packet Connect Terraform
This repository demonstrates setting up end-to-end connectivity between Packet and Azure using Terraform and Packet Connect.

![demo](./tf-packet-connect.gif)

This script will create a project, a Packet Connect object, a single VLAN, and a single bare metal instance in mixed/hybrid networking mode with the first NIC in bonded Layer 3 and the second NIC unbonded in a single VLAN attached to the Packet Connect object.

# Setup

In Azure:

* A virtual machine, virtual network, and virtual network gateway that are all associated to each other
* An ExpressRoute Circuit (provider = Packet)
  * Connectivity between ExpressRoute and your Virtual Network Gateway (Connectivity tab)
  * ExpressRoute configured with Private Peering (primary and secondary /30s can be any RFC 1918 IP space)

In Packet:

* A valid API key, exported as the environment variable `PACKET_AUTH_TOKEN`

# Usage

Clone this repository locally, edit `main.tf` and substitute the `locals` section to the appropriate variables, then:

```
terraform plan
```

Assuming no errors, create the necessary resources with:

```
terraform apply
```

### License

This is provided under the BSD 3-Clause software license.
