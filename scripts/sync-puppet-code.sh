#!/bin/bash
# Sync Puppet code to the master server
# Usage: ./sync-puppet-code.sh <puppet-master-ip>

set -e

PUPPET_MASTER_IP="${1:-}"
REMOTE_USER="${2:-root}"
REMOTE_PATH="/etc/puppetlabs/code/environments/production"

if [ -z "$PUPPET_MASTER_IP" ]; then
    echo "Usage: $0 <puppet-master-ip> [remote-user]"
    echo ""
    echo "This script syncs the local Puppet code to the master server"
    echo "Useful for development/testing before setting up r10k with git"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Syncing Puppet code to $PUPPET_MASTER_IP ==="

# Sync environments
echo "Syncing environments..."
rsync -avz --delete \
    --exclude='.git' \
    --exclude='*.example' \
    --exclude='terraform' \
    --exclude='scripts' \
    --exclude='README.md' \
    "$REPO_ROOT/environments/production/" \
    "${REMOTE_USER}@${PUPPET_MASTER_IP}:${REMOTE_PATH}/"

# Sync custom modules
echo "Syncing modules..."
rsync -avz --delete \
    "$REPO_ROOT/modules/" \
    "${REMOTE_USER}@${PUPPET_MASTER_IP}:${REMOTE_PATH}/modules/"

# Install Puppetfile dependencies
echo "Installing Puppetfile dependencies..."
ssh "${REMOTE_USER}@${PUPPET_MASTER_IP}" "cd ${REMOTE_PATH} && /opt/puppetlabs/puppet/bin/r10k puppetfile install -v"

echo ""
echo "=== Sync complete ==="
echo "Run puppet agent on nodes to apply changes"
