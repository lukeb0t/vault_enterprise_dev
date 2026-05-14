# ─── Identity ─────────────────────────────────────────────────────────────────

variable "cluster_name" {
  description = "Unique name prefix applied to all resources created by this module (e.g. 'vault-poc')."
  type        = string
}

# ─── Vault ────────────────────────────────────────────────────────────────────

variable "vault_version" {
  description = "Vault Enterprise Docker image tag to pull from Docker Hub (e.g. '2.0.0-ent')."
  type        = string
  default     = "2.0.0-ent"
}

variable "vault_license" {
  description = "Vault Enterprise license string. Passed to the container as the VAULT_LICENSE environment variable."
  type        = string
  sensitive   = true
}

# ─── vSphere Infrastructure ───────────────────────────────────────────────────

variable "vsphere_datacenter" {
  description = "Name of the vSphere datacenter where the VM will be deployed."
  type        = string
}

variable "vsphere_compute_cluster" {
  description = "Name of the vSphere compute cluster. Mutually exclusive with vsphere_esxi_host — exactly one must be set."
  type        = string
  default     = null
}

variable "vsphere_esxi_host" {
  description = "FQDN or IP of a standalone ESXi host. Used as the compute target when vsphere_compute_cluster is null."
  type        = string
  default     = null
}

variable "vsphere_datastore" {
  description = "Name of the vSphere datastore where the VM disk will be created."
  type        = string
}

variable "vsphere_network" {
  description = "Name of the vSphere port group (network) to attach the VM NIC to."
  type        = string
}

variable "vm_template" {
  description = "Name of the VM template to clone. Must be a RHEL 8-compatible template with cloud-init and open-vm-tools installed."
  type        = string
  default     = "rhel8-template"
}

variable "vm_folder" {
  description = "vSphere VM folder path for the deployed VM (e.g. 'vault'). Leave null to place in the datacenter root."
  type        = string
  default     = null
}

# ─── Networking (Static IP) ───────────────────────────────────────────────────

variable "vault_ip_address" {
  description = "Static IPv4 address to assign to the Vault VM (e.g. '10.140.21.100'). Embedded into the TLS SAN and Vault api_addr."
  type        = string
}

variable "netmask_bits" {
  description = "IPv4 prefix length for the Vault VM's NIC (e.g. 24 for a /24 subnet)."
  type        = number
  default     = 24
}

variable "gateway" {
  description = "IPv4 default gateway for the Vault VM."
  type        = string
}

variable "dns_servers" {
  description = "List of DNS server addresses for the Vault VM."
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

variable "dns_search_domains" {
  description = "DNS search domain suffixes for the Vault VM."
  type        = list(string)
  default     = []
}

variable "domain" {
  description = "Domain component of the VM's fully-qualified hostname (e.g. 'example.local')."
  type        = string
  default     = "local"
}

# ─── VM Sizing ────────────────────────────────────────────────────────────────

variable "num_cpus" {
  description = "Number of virtual CPUs allocated to the Vault VM."
  type        = number
  default     = 2
}

variable "memory_mb" {
  description = "Memory in megabytes allocated to the Vault VM."
  type        = number
  default     = 4096
}

variable "disk_size_gb" {
  description = "Size in GiB of the VM's primary disk. Raft storage shares this disk. Must be >= template disk size."
  type        = number
  default     = 50
}

# ─── TLS ──────────────────────────────────────────────────────────────────────

variable "vault_tls_cert_pem" {
  description = "Optional PEM-encoded TLS certificate for Vault listener. When set, vault_tls_key_pem must also be set. If empty, cloud-init generates a self-signed cert."
  type        = string
  sensitive   = true
  default     = ""
}

variable "vault_tls_key_pem" {
  description = "Optional PEM-encoded private key for Vault listener TLS certificate. When set, vault_tls_cert_pem must also be set."
  type        = string
  sensitive   = true
  default     = ""
}

variable "tls_disable_client_certs" {
  description = "Whether Vault should disable client certificate requests on the HTTPS listener."
  type        = bool
  default     = true
}

# ─── Tags / Annotation ────────────────────────────────────────────────────────

variable "annotation" {
  description = "Free-text VM annotation (description) visible in the vSphere console. Appended to the auto-generated annotation."
  type        = string
  default     = ""
}
