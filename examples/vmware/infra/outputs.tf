output "vault_addr" {
  description = "Vault API address."
  value       = module.vault.vault_addr
}

output "vault_ip" {
  description = "Static IP address of the Vault VM."
  value       = module.vault.vault_ip
}

output "vm_id" {
  description = "vSphere MoRef ID of the Vault VM."
  value       = module.vault.vm_id
}

output "bootstrap_file" {
  description = "Path on the VM to the bootstrap credentials file."
  value       = module.vault.barebones_bootstrap_file
}
