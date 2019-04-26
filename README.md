# Packet Connect Terraform
This terraform script demonstrates end-to-end connectivity with Azure, provisioned on Packet using terraform.

This script will create a project, a Packet Connect object, a single VLAN, and a single bare metal instance in mixed/hybrid networking mode with the first NIC in bonded Layer 3 and the second NIC unbonded in a single VLAN attached to the Packet Connect object.

# Setup

There are several things you need to setup in your Microsoft Azure account:

* A virtual machine, virtual network, and virtual network gateway that are all associated to each other
* An ExpressRoute Circuit (provider = Packet)
** Connectivity between ExpressRoute and your Virtual Network Gateway (Connectivity tab)
** ExpressRoute configured with Private Peering (primary and secondary /30s can be any RFC 1918 IP space)

On Packet, you must have:

* A valid API key, exported as the environment variable `PACKET_AUTH_TOKEN`

# Usage

Edit `create.tf` and substitute the `locals` section to the appropriate settings, then:

```
terraform plan
terraform apply
```

### License

This is provided under the BSD 3-Clause software license.
