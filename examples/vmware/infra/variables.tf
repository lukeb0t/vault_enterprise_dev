# ─── vSphere Provider ─────────────────────────────────────────────────────────

variable "vsphere_server" {
  description = "Hostname or IP of the vCenter Server."
  type        = string
}

variable "vsphere_user" {
  description = "vSphere username (e.g. 'root' or 'administrator@vsphere.local')."
  type        = string
  sensitive   = true
}

variable "vsphere_password" {
  description = "vSphere password."
  type        = string
  sensitive   = true
}

variable "vsphere_allow_unverified_ssl" {
  description = "Allow unverified TLS certificates from the vCenter API. Set true for lab environments with self-signed certs."
  type        = bool
  default     = false
}

# ─── Vault ────────────────────────────────────────────────────────────────────

variable "cluster_name" {
  type    = string
  default = "vault-poc"
}

variable "vault_version" {
  type    = string
  default = "2.0.0-ent"
}

variable "vault_license" {
  type      = string
  sensitive = true
}

# ─── vSphere Infrastructure ───────────────────────────────────────────────────

variable "vsphere_datacenter" {
  type = string
}

variable "vsphere_compute_cluster" {
  type    = string
  default = null
}

variable "vsphere_esxi_host" {
  type    = string
  default = null
}

variable "vsphere_datastore" {
  type = string
}

variable "vsphere_network" {
  type = string
}

variable "vm_template" {
  type    = string
  default = "rhel8-template"
}

variable "vm_folder" {
  type    = string
  default = null
}

# ─── Static IP ────────────────────────────────────────────────────────────────

variable "vault_ip_address" {
  type = string
}

variable "gateway" {
  type = string
}

variable "netmask_bits" {
  type    = number
  default = 24
}

variable "dns_servers" {
  type    = list(string)
  default = ["8.8.8.8", "8.8.4.4"]
}

variable "dns_search_domains" {
  type    = list(string)
  default = []
}

variable "domain" {
  type    = string
  default = "local"
}

# ─── TLS ──────────────────────────────────────────────────────────────────────

variable "vault_tls_cert_pem" {
  type      = string
  sensitive = true
  default   = ""
}

variable "vault_tls_key_pem" {
  type      = string
  sensitive = true
  default   = ""
}
