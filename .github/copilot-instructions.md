# Copilot instructions: vault_enterprise_dev

Terraform modules that deploy a **single-node HashiCorp Vault Enterprise** cluster
(Vault runs as a `hashicorp/vault-enterprise` Docker container with Raft integrated
storage) onto AWS, Azure, or VMware vSphere. There is no application code — this repo
is entirely Terraform (HCL) plus Bash cloud-init bootstrap templates.

## Repository layout

- `vault_deploy_aws/`, `vault_deploy_azure/`, `vault_deploy_vmware/` — the reusable
  modules. Each is self-contained with the same file layout:
  `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, and
  `templates/cloud-init.sh.tpl`.
- `examples/<cloud>/infra/` — thin, ready-to-apply root configs that call the
  matching module via a relative `source = "../../vault_deploy_<cloud>"`.
- `vault_deploy_vmware/` is **WIP / untested** (see git history) — treat it as less
  mature than the AWS and Azure modules.

## Architecture — the big picture

The AWS and Azure modules are **deliberately equivalent and interchangeable**: same
single-node Vault deployment, only the cloud primitives differ. When you change
behavior in one, check whether the sibling module needs the same change to stay in
parity. The README's comparison table is the source of truth for the mapping:

| Concern | AWS | Azure | VMware |
|---|---|---|---|
| Compute | EC2 (Amazon Linux 2023) | Linux VM (Ubuntu 22.04) | Cloned RHEL 8 template |
| Auto-unseal | AWS KMS CMK | Azure Key Vault RSA key | **Shamir** (no cloud KMS) |
| Secret storage | SSM Parameter Store | Key Vault Secret | `init.json` on disk (SSH to retrieve) |
| Identity | IAM Instance Profile | User-Assigned Managed Identity | n/a |
| Bootstrap channel | `user_data` | `custom_data` | `guestinfo.userdata` |

Deployment flow is the same everywhere: Terraform provisions cloud primitives →
injects values into `templates/cloud-init.sh.tpl` via `templatefile()` → the VM boots,
installs Docker, writes Vault config, starts the container, and runs
`vault operator init` automatically. The Terraform layer never talks to Vault's API;
all Vault setup happens inside the cloud-init script.

## Key conventions

- **`cluster_name` is the universal prefix** for every created resource and for
  isolating per-deployment namespaces (e.g. AWS SSM paths are
  `/<ssm_path_prefix>/<cluster_name>/...`). Reuse it; don't hardcode names.
- **Optional BYO networking via a `*_id == null` toggle.** When `vpc_id`/`vnet_id` is
  `null` the module creates its own network; when set, the caller must also pass the
  matching `subnet_id`. This is implemented with `count` + a `local.create_networking`
  flag and `*_resolved` locals — follow that pattern for any new
  "manage-it or bring-your-own" input.
- **`barebones_dev_mode`** disables cloud KMS/secret storage and falls back to
  SSH-based bootstrap. Several locals key off it (e.g. `kms_enabled = !barebones`).
- **TLS is on by default** with an auto-generated self-signed cert; passing both
  `vault_tls_cert_pem` and `vault_tls_key_pem` switches to BYO cert (detected via a
  `custom_tls_enabled` local). Certs/keys are base64-encoded before injection into
  cloud-init.
- **Tagging:** AWS uses a `local.common_tags` (`Module`, `ClusterName`) merged with
  user `var.tags` on every resource — extend this local rather than tagging ad hoc.
- **`sensitive = true`** on `vault_license` and any token/key variable. Never echo
  these in outputs or logs.
- **Style:** section headers use `# ─── Section ───` box-drawing dividers; inline
  comments explain *why* (e.g. container UID 100 ownership, RBAC propagation waits),
  not *what*. Match this when adding code.
- **Cloud-init scripts** use `set -euo pipefail`, a `log()` helper timestamping to
  `/var/log/vault-cloud-init.log`, and reference Terraform values as `${var_name}`
  placeholders documented in a header block. Keep that header list in sync when you
  add a template variable.

## Working with Terraform here

- `terraform` `>= 1.5.0` required by every module.
- Validate/format changes from within the module or example dir:
  ```bash
  cd vault_deploy_aws        # or any module / examples/<cloud>/infra
  terraform fmt -recursive
  terraform init
  terraform validate
  ```
- Full apply requires live cloud credentials (`aws configure` / `az login` / vSphere)
  and a Vault Enterprise license — only run against an account you intend to bill.
- A typical end-to-end run:
  ```bash
  cd examples/aws/infra
  cp terraform.tfvars.example terraform.tfvars   # then edit
  terraform init && terraform apply
  ```
- `.tfvars` (except `*.tfvars.example`), `.tfstate`, and `.terraform/` are gitignored.
  Never commit real licenses, tokens, or state. Note: some example dirs currently have
  committed state/tfvars — do not add more.
