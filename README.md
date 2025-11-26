# Puppet + SOPS + Tomcat Infrastructure

This repository contains infrastructure-as-code for a 3-node Puppet setup with SOPS-encrypted secrets and Tomcat application servers.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Hetzner Cloud                            │
│  ┌─────────────────┐   ┌─────────────────┐                 │
│  │  puppet-master  │   │  Private Network│                 │
│  │  (10.0.1.10)    │   │  10.0.1.0/24    │                 │
│  │                 │   └─────────────────┘                 │
│  │  - Puppet 8     │                                       │
│  │  - SOPS + age   │                                       │
│  │  - r10k         │                                       │
│  └────────┬────────┘                                       │
│           │                                                │
│     ┌─────┴─────┐                                         │
│     │           │                                         │
│  ┌──▼──┐     ┌──▼──┐                                      │
│  │tomcat-1│   │tomcat-2│                                   │
│  │10.0.1.20│  │10.0.1.21│                                  │
│  │         │  │         │                                  │
│  │Tomcat 9 │  │Tomcat 9 │                                  │
│  │:8080    │  │:8080    │                                  │
│  └─────────┘  └─────────┘                                  │
└─────────────────────────────────────────────────────────────┘
```

## Components

- **Terraform**: Provisions Hetzner Cloud infrastructure
- **Puppet 8**: Configuration management
- **SOPS + age**: Secret encryption/decryption
- **Tomcat 9**: Application server with secrets in context.xml

## Quick Start

### 1. Install Prerequisites

```bash
# macOS
brew install terraform sops age

# Or download from:
# - https://www.terraform.io/downloads
# - https://github.com/getsops/sops/releases
# - https://github.com/FiloSottile/age/releases
```

### 2. Set Up SOPS Keys

```bash
./scripts/setup-sops-keys.sh
```

This generates an age key pair. Note the public key for the next step.

### 3. Configure SOPS

Update `.sops.yaml` with your age public key:

```yaml
creation_rules:
  - path_regex: environments/.*/hieradata/secrets/.*\.yaml$
    age: age1your-actual-public-key-here
```

### 4. Initialize Secrets

```bash
# Set your age public key
export SOPS_AGE_RECIPIENTS="age1your-public-key"

# Create and encrypt secret files
./scripts/init-secrets.sh
```

### 5. Deploy Infrastructure

```bash
cd terraform

# Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Hetzner API token

# Deploy
terraform init
terraform plan
terraform apply
```

### 6. Sync Puppet Code

```bash
# Get the Puppet master IP from Terraform output
terraform output puppet_master_ip

# Sync code to master
./scripts/sync-puppet-code.sh <puppet-master-ip>
```

## Managing Secrets

### Editing Encrypted Files

```bash
# Set your age key file
export SOPS_AGE_KEY_FILE=~/.sops/age-key.txt

# Edit secrets (opens in $EDITOR)
sops environments/production/hieradata/secrets/common.yaml
```

### Adding New Secrets

1. Create a new YAML file in `environments/production/hieradata/secrets/`
2. Encrypt it: `sops --encrypt --in-place <file>`
3. Reference in Hiera or Puppet manifests

### Secret Hierarchy

Secrets are looked up in this order (first match wins):
1. `secrets/nodes/%{certname}.yaml` - Per-node secrets
2. `secrets/roles/%{role}.yaml` - Per-role secrets
3. `secrets/common.yaml` - Common secrets

## Directory Structure

```
.
├── terraform/              # Infrastructure as code
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── templates/          # Cloud-init templates
├── environments/
│   └── production/
│       ├── manifests/      # Node definitions
│       ├── hieradata/      # Hiera data
│       │   ├── common.yaml
│       │   ├── nodes/
│       │   ├── roles/
│       │   └── secrets/    # SOPS encrypted
│       └── hiera.yaml      # Hiera config
├── modules/
│   ├── sops/               # SOPS Hiera backend
│   ├── profile_tomcat/     # Tomcat profile
│   └── profile_puppet_master/
├── scripts/                # Helper scripts
└── Puppetfile              # Module dependencies
```

## Tomcat Configuration

Secrets are injected into Tomcat's `context.xml`:

```xml
<Resource name="jdbc/AppDB"
          username="<%= $db_username %>"
          password="<%= $db_password %>"
          url="<%= $db_url %>" />

<Environment name="app/apiKey"
             value="<%= $api_key %>" />
```

Available secret parameters (from Hiera):
- `profile_tomcat::db_username`
- `profile_tomcat::db_password`
- `profile_tomcat::db_url`
- `profile_tomcat::api_key`
- `profile_tomcat::api_secret`
- `profile_tomcat::session_secret`

## Security Notes

1. **Never commit unencrypted secrets** - All files in `secrets/` should be SOPS-encrypted
2. **Protect your age private key** - Keep `~/.sops/age-key.txt` secure
3. **Use separate keys per environment** - Production should use different keys
4. **Rotate secrets regularly** - Re-encrypt files when rotating keys

## Troubleshooting

### SOPS decryption fails on Puppet master

Check that the age key is in place:
```bash
ls -la /etc/puppetlabs/puppet/sops/age-key.txt
```

### Puppet agent can't connect

Verify DNS/hosts resolution:
```bash
ping puppet-master
```

Check certificate signing:
```bash
# On master
puppetserver ca list --all
```

### Tomcat won't start

Check logs:
```bash
tail -f /opt/tomcat9/logs/catalina.out
journalctl -u tomcat -f
```

## License

MIT
