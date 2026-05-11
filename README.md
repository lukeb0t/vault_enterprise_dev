# vault_enterprise_dev

Terraform modules for deploying **HashiCorp Vault Enterprise** on AWS and Azure. Designed to provision a single-node Vault Enterprise cluster with auto-unseal, TLS, and cloud-native secret storage for bootstrap credentials.

---

## Modules

### [`vault_deploy_aws`](./vault_deploy_aws/) — Deploy Vault on AWS

Self-contained AWS deployment. Creates its own VPC and networking by default.

| Input | Description | Default |
|---|---|---|
| `cluster_name` | Name prefix for all resources | required |
| `vault_version` | Docker image tag | `"2.0.0-ent"` |
| `vault_license` | Enterprise license (sensitive) | required |
| `vpc_id` | Existing VPC (`null` = module creates one) | `null` |
| `subnet_id` | Existing subnet (required when `vpc_id` set) | `null` |
| `key_pair_name` | EC2 key pair for SSH access | `null` |

Key outputs: `vault_addr`, `vault_public_ip`, `ssm_root_token_path`, `ssm_tls_cert_b64_path`, `iam_role_arn`

→ See [`vault_deploy_aws/README.md`](./vault_deploy_aws/README.md) for full input/output reference.

---

### [`vault_deploy_azure`](./vault_deploy_azure/) — Deploy Vault on Azure

Self-contained Azure deployment. Creates its own VNet and networking by default.

| Input | Description | Default |
|---|---|---|
| `cluster_name` | Name prefix for all resources | required |
| `vault_version` | Docker image tag | `"2.0.0-ent"` |
| `vault_license` | Enterprise license (sensitive) | required |
| `location` | Azure region | required |
| `resource_group_name` | Existing Resource Group | required |
| `admin_ssh_public_key` | SSH public key for `azureuser` | required |
| `vnet_id` | Existing VNet (`null` = module creates one) | `null` |
| `subnet_id` | Existing subnet (required when `vnet_id` set) | `null` |

Key outputs: `vault_addr`, `vault_public_ip`, `key_vault_name`, `key_vault_uri`

→ See [`vault_deploy_azure/README.md`](./vault_deploy_azure/README.md) for full input/output reference.

---

## What these modules deploy

`vault_deploy_aws` and `vault_deploy_azure` are **equivalent, interchangeable modules**. Both deploy an identical single-node Vault Enterprise cluster; only the underlying cloud primitives differ.

| | `vault_deploy_aws` | `vault_deploy_azure` |
|---|---|---|
| **Compute** | EC2 (Amazon Linux 2023) | Linux VM (Ubuntu 22.04 LTS) |
| **Instance size** | `m5.medium` | `Standard_B2s` |
| **Auto-unseal** | AWS KMS Customer Managed Key | Azure Key Vault RSA key |
| **Secret storage** | SSM Parameter Store (SecureString) | Azure Key Vault Secret |
| **Identity** | IAM Instance Profile | User-Assigned Managed Identity |
| **Networking** | VPC + subnet (auto or BYOVPC) | VNet + subnet (auto or BYOVNET) |
| **Public IP** | Elastic IP (pre-allocated) | Static Standard-SKU Public IP (pre-allocated) |
| **Bootstrap** | cloud-init via `user_data` | cloud-init via `custom_data` |
| **Vault config** | `seal "awskms"` | `seal "azurekeyvault"` |
| **Root token retrieval** | `aws ssm get-parameter ...` | `az keyvault secret show ...` |

Both modules:
- Run Vault Enterprise as a Docker container (`hashicorp/vault-enterprise`)
- Use Raft integrated storage
- TLS enabled by default via auto-generated self-signed certificate (BYO Cert/Key also supported)
- Barebones dev mode available for SSH-based bootstrap without cloud secret storage
- Run `vault operator init` automatically via cloud-init
- Support BYOVPC / BYOVNET via optional inputs

---

## Prerequisites

| Requirement | AWS | Azure |
|---|---|---|
| Terraform | ≥ 1.3 | ≥ 1.3 |
| CLI auth | `aws configure` or `AWS_*` env vars | `az login` or `ARM_*` env vars |
| IAM/RBAC permissions | EC2, VPC, IAM, KMS, SSM | Contributor + Key Vault Administrator |
| Vault Enterprise license | required | required |

---

## Quick start

```bash
# AWS
cd vault_deploy_aws
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars
terraform init && terraform apply

# Azure
cd vault_deploy_azure
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars
terraform init && terraform apply
```

---
