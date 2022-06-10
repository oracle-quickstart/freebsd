# ------ Create HUB VCN
resource "oci_core_vcn" "hub" {
  count          = local.use_existing_network ? 0 : 1
  cidr_block     = var.vcn_cidr_block
  dns_label      = var.vcn_dns_label
  compartment_id = var.network_compartment_ocid
  display_name   = var.vcn_display_name
}

# ------ Create IGW
resource "oci_core_internet_gateway" "igw" {
  count          = local.use_existing_network ? 0 : 1
  compartment_id = var.network_compartment_ocid
  display_name   = "${var.vcn_display_name}-igw"
  vcn_id         = oci_core_vcn.hub[count.index].id
  enabled        = "true"
}

# ------ Create DRG
resource "oci_core_drg" "drg" {
  compartment_id = var.network_compartment_ocid
  display_name   = "${var.vcn_display_name}-drg"
}

# ------ Default Routing Table for Hub VCN 
resource "oci_core_default_route_table" "default_route_table" {
  count                      = local.use_existing_network ? 0 : 1
  manage_default_resource_id = oci_core_vcn.hub[count.index].default_route_table_id
  display_name               = "DefaultRouteTable"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw[count.index].id
  }
}

# ------ Default Routing Table for Hub VCN 
resource "oci_core_route_table" "untrust_route_table" {
  count          = local.use_existing_network ? 0 : 1
  compartment_id = var.network_compartment_ocid
  vcn_id         = oci_core_vcn.hub[count.index].id
  display_name   = var.public_routetable_display_name

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw[count.index].id
  }

  route_rules {
    destination       = "172.16.0.0/16"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_drg.drg.id
  }

  route_rules {
    destination       = "10.0.0.0/24"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_drg.drg.id
  }

  route_rules {
    destination       = "10.0.1.0/24"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_drg.drg.id
  }
}

# ------ Get All Services Data Value 
data "oci_core_services" "all_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

# ------ Create Hub Service Gateway (Hub VCN)
resource "oci_core_service_gateway" "hub_service_gateway" {
  count          = local.use_existing_network ? 0 : 1
  compartment_id = var.network_compartment_ocid
  vcn_id         = oci_core_vcn.hub[count.index].id
  services {
    service_id = data.oci_core_services.all_services.services[0]["id"]
  }
  display_name   = "hubServiceGateway"
}

# ------ Get Hub Service Gateway from Gateways (Hub VCN)
data "oci_core_service_gateways" "hub_service_gateways" {
  count          = local.use_existing_network ? 0 : 1
  compartment_id = var.network_compartment_ocid
  state          = "AVAILABLE"
  vcn_id         = oci_core_vcn.hub[count.index].id
}

# ------ Create Hub VCN Public subnet
resource "oci_core_subnet" "mangement_subnet" {
  count                      = local.use_existing_network ? 0 : 1
  compartment_id             = var.network_compartment_ocid
  vcn_id                     = oci_core_vcn.hub[count.index].id
  cidr_block                 = var.mangement_subnet_cidr_block
  display_name               = var.mangement_subnet_display_name
  route_table_id             = oci_core_vcn.hub[count.index].default_route_table_id
  dns_label                  = var.mangement_subnet_dns_label
  security_list_ids          = [data.oci_core_security_lists.allow_all_security.security_lists[0].id]
  prohibit_public_ip_on_vnic = "false"

  depends_on = [
    oci_core_security_list.allow_all_security,
  ]
}

# ------ Update Default Security List to All All  Rules
resource "oci_core_security_list" "allow_all_security" {
  compartment_id = var.network_compartment_ocid
  vcn_id         = local.use_existing_network ? var.vcn_id : oci_core_vcn.hub.0.id
  display_name   = "AllowAll"
  ingress_security_rules {
    protocol = "all"
    source   = "0.0.0.0/0"
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}