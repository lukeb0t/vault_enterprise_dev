module "vault" {
  source = "../../../vault_deploy_vmware"

  cluster_name  = var.cluster_name
  vault_version = var.vault_version
  vault_license = var.vault_license

  vsphere_datacenter      = var.vsphere_datacenter
  vsphere_compute_cluster = var.vsphere_compute_cluster
  vsphere_esxi_host       = var.vsphere_esxi_host
  vsphere_datastore       = var.vsphere_datastore
  vsphere_network         = var.vsphere_network
  vm_template             = var.vm_template
  vm_folder               = var.vm_folder

  vault_ip_address   = var.vault_ip_address
  gateway            = var.gateway
  netmask_bits       = var.netmask_bits
  dns_servers        = var.dns_servers
  dns_search_domains = var.dns_search_domains
  domain             = var.domain

  vault_tls_cert_pem = var.vault_tls_cert_pem
  vault_tls_key_pem  = var.vault_tls_key_pem
}
