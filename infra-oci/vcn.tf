locals {
  name            = var.project_name
  oke_nsg_name    = "${local.name}-oke"
  lb_nsg_name     = "${local.name}-lb"
  subnet_cidr_vcn = "10.0.0.0/16"
  subnet_cidr_lb  = "10.0.1.0/24"
  subnet_cidr_oke = "10.0.2.0/24"
}

# ─── VCN ───────────────────────────────────────────────
resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.name}-vcn"
  dns_label      = "${local.name}vcn"
  cidr_blocks    = [local.subnet_cidr_vcn]
}

# ─── Internet Gateway ─────────────────────────────────
resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.name}-igw"
}

# ─── Subnets ───────────────────────────────────────────
resource "oci_core_subnet" "lb" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  display_name               = "${local.name}-lb-subnet"
  dns_label                  = "lb"
  cidr_block                 = local.subnet_cidr_lb
  prohibit_public_ip_on_vnic = true # LB через OKE Service, не прямий доступ
}

resource "oci_core_subnet" "oke" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  display_name               = "${local.name}-oke-subnet"
  dns_label                  = "oke"
  cidr_block                 = local.subnet_cidr_oke
  prohibit_public_ip_on_vnic = true
}

# ─── Route Table ──────────────────────────────────────
resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.name}-public-rt"
  route_rules {
    network_entity_id = oci_core_internet_gateway.main.id
    destination       = "0.0.0.0/0"
    description       = "Internet access"
  }
}

resource "oci_core_route_table_attachment" "lb" {
  subnet_id      = oci_core_subnet.lb.id
  route_table_id = oci_core_route_table.public.id
}

resource "oci_core_route_table_attachment" "oke" {
  subnet_id      = oci_core_subnet.oke.id
  route_table_id = oci_core_route_table.public.id
}

# ─── Security Lists ───────────────────────────────────
resource "oci_core_security_list" "lb" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.name}-lb-sl"

  # HTTP from internet
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 80
      max = 80
    }
  }
  # HTTPS from internet
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
  }
  # All egress
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

resource "oci_core_security_list" "oke" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.name}-oke-sl"

  # OKE cluster communication (TCP 10250)
  ingress_security_rules {
    protocol = "6"
    source   = local.subnet_cidr_vcn
    tcp_options {
      min = 10250
      max = 10250
    }
  }
  # NodePort range for services
  ingress_security_rules {
    protocol = "6"
    source   = local.subnet_cidr_lb
    tcp_options {
      min = 30000
      max = 32767
    }
  }
  # All internal
  ingress_security_rules {
    protocol = "all"
    source   = local.subnet_cidr_vcn
  }
  # All egress
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}
