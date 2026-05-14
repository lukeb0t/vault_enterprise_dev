# vault_deploy_vmware

Terraform module that deploys a single-node Vault Enterprise server into a VMware vSphere environment. The module clones a RHEL 8 VM template, applies a static IP via vSphere Guest Customization, and bootstraps Vault Enterprise inside a Docker container via cloud-init.

## How it works

1. **Clone** — Terraform clones the specified VM template.
2. **Guest Customization** — vSphere sets the static IP, hostname, DNS, and gateway via VMware Tools before first boot.
3. **Cloud-init (GuestInfo)** — A bootstrap shell script is injected via `guestinfo.userdata` and executed by cloud-init on first boot. It installs Docker CE, configures Vault, starts the container, and initializes Vault with Shamir unseal.
4. **Bootstrap credentials** — The root token and unseal key are written to `/opt/vault/bootstrap/init.json` (mode `600`, root-only). Retrieve them via SSH after deployment.

> **Unseal model:** VMware has no native cloud key management service, so this module always uses **Shamir unseal** with one key share. For production, consider configuring a [Vault Transit seal](https://developer.hashicorp.com/vault/docs/configuration/seal/transit) against an external Vault cluster after initial deployment.

## Prerequisites

| Requirement | Notes |
|---|---|
| Terraform ≥ 1.5.0 | |
| vSphere provider `~> 2.6` | `hashicorp/vsphere` |
| VM template | RHEL 8-compatible with `cloud-init ≥ 21.3`, `open-vm-tools`, and the **VMwareGuestInfo datasource** |
| cloud-init datasource | RHEL 8.4+ ships the VMwareGuestInfo datasource built-in. For older RHEL 8 releases, install `cloud-init-vmware-guestinfo`. |
| Outbound internet access | The VM pulls Docker CE packages and the `hashicorp/vault-enterprise` image from Docker Hub on first boot. |

### Verify cloud-init datasource on the template

```bash
grep -r VMwareGuestInfo /etc/cloud/cloud.cfg /etc/cloud/cloud.cfg.d/ 2>/dev/null \
  || python3 -c "import cloudinit.sources.DataSourceVMwareGuestInfo" 2>/dev/null \
  && echo "VMwareGuestInfo datasource available"
```

If the datasource is missing, add it to `/etc/cloud/cloud.cfg.d/99-datasource.cfg` on the template:

```yaml
datasource_list:
  - VMwareGuestInfo
  - OVF
  - None
```

## Usage

```hcl
provider "vsphere" {
  vsphere_server       = "10.140.21.5"
  user                 = "root"
  password             = var.vsphere_password
  allow_unverified_ssl = true
}

module "vault" {
  source = "./vault_deploy_vmware"

  cluster_name  = "vault-poc"
  vault_license = var.vault_license

  vsphere_datacenter = "ha-datacenter"
  vsphere_esxi_host  = "10.140.21.5"
  vsphere_datastore  = "datastore1"
  vsphere_network    = "VM Network"
  vm_template        = "rhel8-template"

  vault_ip_address = "10.140.21.100"
  gateway          = "10.140.21.1"
  netmask_bits     = 24
  dns_servers      = ["10.140.21.1", "8.8.8.8"]
}
```

See [examples/vmware/infra](../examples/vmware/infra) for a ready-to-use deployment.

## Retrieving bootstrap credentials

After `terraform apply` completes:

```bash
# SSH into the Vault VM
ssh root@<vault_ip_address>

# Read the bootstrap credentials
sudo cat /opt/vault/bootstrap/init.json

# Set environment variables
export VAULT_ADDR="https://<vault_ip_address>:8200"
export VAULT_SKIP_VERIFY=true   # if using the self-signed cert
export VAULT_TOKEN="<root_token_from_init.json>"

# Verify
vault status
```

To copy the self-signed TLS certificate for use as `VAULT_CACERT`:

```bash
scp root@<vault_ip_address>:/opt/vault/certs/vault.crt ./vault-ca.crt
export VAULT_CACERT=./vault-ca.crt
```

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `cluster_name` | Name prefix for all resources | `string` | — | yes |
| `vault_version` | Vault Enterprise Docker image tag | `string` | `"2.0.0-ent"` | no |
| `vault_license` | Vault Enterprise license string | `string` | — | yes |
| `vsphere_datacenter` | vSphere datacenter name | `string` | — | yes |
| `vsphere_compute_cluster` | Compute cluster name (mutually exclusive with `vsphere_esxi_host`) | `string` | `null` | no |
| `vsphere_esxi_host` | Standalone ESXi host FQDN or IP | `string` | `null` | no |
| `vsphere_datastore` | Datastore name | `string` | — | yes |
| `vsphere_network` | Port group / network name | `string` | — | yes |
| `vm_template` | VM template name to clone | `string` | `"rhel8-template"` | no |
| `vm_folder` | vSphere VM folder path | `string` | `null` | no |
| `vault_ip_address` | Static IPv4 address for the Vault VM | `string` | — | yes |
| `gateway` | Default gateway | `string` | — | yes |
| `netmask_bits` | Subnet prefix length | `number` | `24` | no |
| `dns_servers` | DNS server list | `list(string)` | `["8.8.8.8","8.8.4.4"]` | no |
| `domain` | Domain for VM hostname | `string` | `"local"` | no |
| `num_cpus` | vCPUs | `number` | `2` | no |
| `memory_mb` | Memory in MB | `number` | `4096` | no |
| `disk_size_gb` | Disk size in GiB | `number` | `50` | no |
| `vault_tls_cert_pem` | Custom TLS certificate PEM | `string` | `""` | no |
| `vault_tls_key_pem` | Custom TLS key PEM | `string` | `""` | no |
| `tls_disable_client_certs` | Disable mTLS client cert requests | `bool` | `true` | no |

## Outputs

| Name | Description |
|---|---|
| `vault_addr` | Vault HTTPS API address |
| `vault_ip` | Static IP of the Vault VM |
| `vm_id` | vSphere MoRef ID of the VM |
| `vm_name` | VM name in vSphere |
| `barebones_bootstrap_file` | Path to bootstrap credentials on the VM |
| `vault_tls_cert_host_path` | Path to TLS certificate on the VM |
