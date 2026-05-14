output "vault_addr" {
  description = "HTTPS address of the Vault server (use as VAULT_ADDR)."
  value       = "https://${var.vault_ip_address}:8200"
}

output "vault_ip" {
  description = "Static IP address assigned to the Vault server."
  value       = var.vault_ip_address
}

output "vm_id" {
  description = "vSphere managed object reference ID (MoRef) of the Vault VM."
  value       = vsphere_virtual_machine.vault.id
}

output "vm_name" {
  description = "Name of the Vault VM in vSphere."
  value       = vsphere_virtual_machine.vault.name
}

output "vm_default_ip_address" {
  description = "Default IP address reported by VMware Tools (matches vault_ip after guest customization)."
  value       = vsphere_virtual_machine.vault.default_ip_address
}

output "vault_tls_cert_host_path" {
  description = "Path on the VM where the TLS certificate is stored. Copy via SSH to use as VAULT_CACERT locally."
  value       = "/opt/vault/certs/vault.crt"
}

output "barebones_bootstrap_file" {
  description = "Local host path of the init JSON file containing the root token and unseal key. Retrieve via SSH: sudo cat /opt/vault/bootstrap/init.json"
  value       = "${local.bootstrap_dir}/init.json"
}
