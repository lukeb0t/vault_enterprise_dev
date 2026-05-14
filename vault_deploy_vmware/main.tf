# ─── vSphere Data Sources ─────────────────────────────────────────────────────
# Look up vSphere objects by name so the module doesn't need hardcoded IDs.

data "vsphere_datacenter" "dc" {
  name = var.vsphere_datacenter
}

data "vsphere_datastore" "ds" {
  name          = var.vsphere_datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

# Either a compute cluster (HA/DRS) or a standalone ESXi host must be supplied.
data "vsphere_compute_cluster" "cluster" {
  count         = var.vsphere_compute_cluster != null ? 1 : 0
  name          = var.vsphere_compute_cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_host" "host" {
  count         = var.vsphere_esxi_host != null ? 1 : 0
  name          = var.vsphere_esxi_host
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "vault" {
  name          = var.vsphere_network
  datacenter_id = data.vsphere_datacenter.dc.id
}

# Read the template's metadata (guest_id, firmware, disk config, NIC type)
# so the cloned VM inherits hardware settings without manual configuration.
data "vsphere_virtual_machine" "template" {
  name          = var.vm_template
  datacenter_id = data.vsphere_datacenter.dc.id
}

locals {
  bootstrap_dir      = "/opt/vault/bootstrap"
  custom_tls_enabled = var.vault_tls_cert_pem != "" && var.vault_tls_key_pem != ""

  # Resolve the resource pool from whichever compute target was supplied.
  resource_pool_id = (
    var.vsphere_compute_cluster != null
    ? data.vsphere_compute_cluster.cluster[0].resource_pool_id
    : data.vsphere_host.host[0].resource_pool_id
  )

  annotation = join("\n", compact([
    "Vault Enterprise ${var.vault_version} — cluster: ${var.cluster_name}",
    "Module: vault_deploy_vmware",
    var.annotation,
  ]))
}

# ─── Cloud-init Change Trigger ────────────────────────────────────────────────
# vSphere has no equivalent of AWS user_data_replace_on_change. This resource
# computes a hash of all cloud-init inputs; when any input changes Terraform
# replaces the VM and re-runs the full bootstrap automatically.

resource "terraform_data" "cloud_init_trigger" {
  input = sha256(join("|", [
    var.vault_version,
    var.vault_license,
    var.cluster_name,
    var.vault_ip_address,
    var.vault_tls_cert_pem,
    var.vault_tls_key_pem,
    tostring(var.tls_disable_client_certs),
  ]))
}

# ─── Vault Virtual Machine ────────────────────────────────────────────────────

resource "vsphere_virtual_machine" "vault" {
  name             = "${var.cluster_name}-vault"
  resource_pool_id = local.resource_pool_id
  datastore_id     = data.vsphere_datastore.ds.id
  folder           = var.vm_folder
  annotation       = local.annotation

  num_cpus = var.num_cpus
  memory   = var.memory_mb

  # Inherit guest OS type and firmware from the template.
  guest_id = data.vsphere_virtual_machine.template.guest_id
  firmware = data.vsphere_virtual_machine.template.firmware

  network_interface {
    network_id   = data.vsphere_network.vault.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  disk {
    label = "disk0"
    # Allow callers to expand beyond the template size; never shrink.
    size             = max(var.disk_size_gb, data.vsphere_virtual_machine.template.disks[0].size)
    thin_provisioned = data.vsphere_virtual_machine.template.disks[0].thin_provisioned
    eagerly_scrub    = data.vsphere_virtual_machine.template.disks[0].eagerly_scrub
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    # vSphere Guest Customization sets the static IP and hostname via VMware Tools
    # before the VM first boots — the same approach as AWS EIP pre-allocation.
    # Cloud-init (below) handles software bootstrap after networking is live.
    customize {
      linux_options {
        host_name = "${var.cluster_name}-vault"
        domain    = var.domain
      }

      network_interface {
        ipv4_address = var.vault_ip_address
        ipv4_netmask = var.netmask_bits
      }

      ipv4_gateway    = var.gateway
      dns_server_list = var.dns_servers
      dns_suffix_list = var.dns_search_domains
    }
  }

  # ─── Cloud-init via VMware GuestInfo ────────────────────────────────────────
  # Equivalent to AWS user_data / Azure custom_data.
  # Requires: cloud-init >= 21.3 (RHEL 8.4+) with the VMwareGuestInfo datasource,
  # or the cloud-init-vmware-guestinfo package on older RHEL 8 releases.
  extra_config = {
    "guestinfo.userdata" = base64encode(templatefile("${path.module}/templates/cloud-init.sh.tpl", {
      cluster_name             = var.cluster_name
      vault_version            = var.vault_version
      vault_license            = var.vault_license
      vault_api_addr           = var.vault_ip_address
      vault_use_custom_tls     = local.custom_tls_enabled ? "true" : "false"
      vault_tls_cert_pem_b64   = local.custom_tls_enabled ? base64encode(var.vault_tls_cert_pem) : ""
      vault_tls_key_pem_b64    = local.custom_tls_enabled ? base64encode(var.vault_tls_key_pem) : ""
      tls_disable_client_certs = var.tls_disable_client_certs ? "true" : "false"
      bootstrap_dir            = local.bootstrap_dir
    }))
    "guestinfo.userdata.encoding" = "base64"
  }

  lifecycle {
    # Replace the VM whenever any cloud-init input changes.
    replace_triggered_by = [terraform_data.cloud_init_trigger]

    precondition {
      condition     = var.vsphere_compute_cluster != null || var.vsphere_esxi_host != null
      error_message = "Exactly one of vsphere_compute_cluster or vsphere_esxi_host must be provided."
    }

    precondition {
      condition     = !(var.vsphere_compute_cluster != null && var.vsphere_esxi_host != null)
      error_message = "vsphere_compute_cluster and vsphere_esxi_host are mutually exclusive — provide only one."
    }

    precondition {
      condition = (
        (var.vault_tls_cert_pem == "" && var.vault_tls_key_pem == "") ||
        (var.vault_tls_cert_pem != "" && var.vault_tls_key_pem != "")
      )
      error_message = "vault_tls_cert_pem and vault_tls_key_pem must both be set together, or both left empty."
    }
  }
}
