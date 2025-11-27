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
- **Tomcat 9.0.83**: Application server with secrets in context.xml

## Directory Structure

```
.
├── terraform/                  # Infrastructure as code
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── templates/              # Cloud-init templates
├── manifests/                  # Puppet node definitions
│   └── site.pp
├── hieradata/                  # Hiera data
│   ├── common.yaml             # Common configuration
│   ├── nodes/                  # Per-node data
│   ├── roles/                  # Per-role data
│   │   └── tomcat.yaml
│   └── secrets/                # SOPS encrypted secrets
│       ├── common.yaml
│       └── roles/
│           └── tomcat.yaml
├── modules/
│   ├── sops/                   # Custom SOPS Hiera backend
│   │   └── lib/puppet/functions/sops_lookup_key.rb
│   ├── profile_tomcat/         # Tomcat profile
│   └── profile_puppet_master/  # Puppet master profile
├── hiera.yaml                  # Hiera configuration
├── .sops.yaml                  # SOPS encryption rules
├── Puppetfile                  # Module dependencies
├── environment.conf            # Puppet environment config
└── scripts/                    # Helper scripts
```

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

### 2. Deploy Infrastructure

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

### 3. Get the Age Public Key from Puppet Master

After deployment, the Puppet master generates its own age key pair. Get the public key:

```bash
ssh root@<puppet-master-ip> 'cat /etc/puppetlabs/puppet/sops/age-public-key.txt'
```

### 4. Configure SOPS Locally

Update `.sops.yaml` with the Puppet master's age public key:

```yaml
creation_rules:
  - path_regex: hieradata/secrets/.*\.yaml$
    age: age1xxxxx...  # Use the public key from step 3
```

### 5. Create and Encrypt Secrets

```bash
# Create a plain text secrets file
cat > hieradata/secrets/common.yaml.plain << 'EOF'
profile_tomcat::db_username: myuser
profile_tomcat::db_password: mypassword
profile_tomcat::db_url: jdbc:postgresql://db.example.com:5432/mydb
profile_tomcat::api_key: my-api-key
profile_tomcat::api_secret: my-api-secret
profile_tomcat::keystore_password: changeit
EOF

# Encrypt and save (copies plain to yaml, then encrypts in place)
cp hieradata/secrets/common.yaml.plain hieradata/secrets/common.yaml
sops --encrypt --in-place hieradata/secrets/common.yaml
```

### 6. Sync Puppet Code to Master

```bash
# Sync all code to puppet master
rsync -avz --exclude '.git' --exclude 'terraform' --exclude '*.plain' \
  ./ root@<puppet-master-ip>:/etc/puppetlabs/code/environments/production/

# Fix permissions
ssh root@<puppet-master-ip> 'chown -R puppet:puppet /etc/puppetlabs/code/environments/production/hieradata/'
```

### 7. Run Puppet on Agents

```bash
# On each tomcat node
puppet agent --test
```

## Managing Secrets

### Editing Encrypted Files

```bash
# Set your age key file (must match the Puppet master's key)
export SOPS_AGE_KEY_FILE=/path/to/age-key.txt

# Edit secrets (opens in $EDITOR)
sops hieradata/secrets/common.yaml
```

### Adding New Secrets

1. Create a `.plain` file with unencrypted content
2. Copy to `.yaml` and encrypt:
   ```bash
   cp myfile.yaml.plain myfile.yaml
   sops --encrypt --in-place myfile.yaml
   ```
3. Sync to Puppet master
4. Run Puppet on agents

### Secret Hierarchy

Secrets are looked up in this order (first match wins):
1. `secrets/nodes/%{trusted.certname}.yaml` - Per-node secrets
2. `secrets/roles/%{facts.role}.yaml` - Per-role secrets
3. `secrets/common.yaml` - Common secrets

## Tomcat Configuration

Secrets are automatically injected into Tomcat's `context.xml` at `/opt/tomcat9/conf/context.xml`:

```xml
<!-- Database connection pool -->
<Resource name="jdbc/AppDB"
          auth="Container"
          type="javax.sql.DataSource"
          url="jdbc:postgresql://db.example.com:5432/appdb"
          username="tomcat_user"
          password="SuperSecret123!"
          ... />

<!-- API credentials -->
<Environment name="app/apiKey" value="api-key-abc123" type="java.lang.String" />
<Environment name="app/apiSecret" value="api-secret-xyz789" type="java.lang.String" />
```

### Available Secret Parameters

| Hiera Key | Description |
|-----------|-------------|
| `profile_tomcat::db_username` | Database username |
| `profile_tomcat::db_password` | Database password |
| `profile_tomcat::db_url` | JDBC connection URL |
| `profile_tomcat::api_key` | API key |
| `profile_tomcat::api_secret` | API secret |
| `profile_tomcat::keystore_password` | Keystore password |
| `profile_tomcat::session_secret` | Session secret |

## How SOPS Integration Works

1. **Hiera Configuration** (`hiera.yaml`): Defines a custom `lookup_key` backend using `sops_lookup_key`

2. **SOPS Lookup Function** (`modules/sops/lib/puppet/functions/sops_lookup_key.rb`):
   - Receives the resolved file path from Hiera
   - Calls `sops --decrypt` with the age key
   - Parses the decrypted YAML and returns the requested key

3. **Age Key Storage**: The Puppet master's private key is stored at `/etc/puppetlabs/puppet/sops/age-key.txt`

4. **Decryption Flow**:
   ```
   Puppet Agent → Puppet Master → Hiera → sops_lookup_key → SOPS CLI → Decrypted Value
   ```

## Security Notes

1. **Never commit unencrypted secrets** - All `.plain` files are in `.gitignore`
2. **Protect age private keys** - Only the Puppet master should have the private key
3. **Use separate keys per environment** - Production should use different keys than dev
4. **Secrets are decrypted server-side** - Only the Puppet master can decrypt; agents receive plaintext values

## Troubleshooting

### SOPS decryption fails on Puppet master

Check that the age key exists and is readable by puppet:
```bash
ls -la /etc/puppetlabs/puppet/sops/age-key.txt
# Should be owned by puppet:puppet with mode 0600
```

Test decryption manually:
```bash
SOPS_AGE_KEY_FILE=/etc/puppetlabs/puppet/sops/age-key.txt \
  sops -d /etc/puppetlabs/code/environments/production/hieradata/secrets/common.yaml
```

### Hiera lookup returns nothing

Test the lookup on the Puppet master:
```bash
puppet lookup profile_tomcat::db_username --explain
```

### Puppet agent can't connect

Check certificate signing:
```bash
# On master
/opt/puppetlabs/bin/puppetserver ca list --all
```

### Tomcat won't start

Check logs:
```bash
tail -f /opt/tomcat9/logs/catalina.out
journalctl -u tomcat -f
```

### Permission denied errors

Ensure hieradata is readable by puppet user:
```bash
chown -R puppet:puppet /etc/puppetlabs/code/environments/production/hieradata/
chmod -R u+r,g+r /etc/puppetlabs/code/environments/production/hieradata/
```

## Current Deployment

| Server | Public IP | Private IP | Role |
|--------|-----------|------------|------|
| puppet-master | 167.235.76.159 | 10.0.1.10 | Puppet Server, SOPS |
| tomcat-1 | 116.203.113.96 | 10.0.1.20 | Tomcat App Server |
| tomcat-2 | 91.99.69.239 | 10.0.1.21 | Tomcat App Server |

## License

MIT
