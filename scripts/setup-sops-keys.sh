#!/bin/bash
# Script to set up SOPS with age encryption locally
# Run this on your development machine to generate keys and configure SOPS

set -e

echo "=== SOPS + age Setup Script ==="

# Check for required tools
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: $1 is not installed"
        echo "Install with: $2"
        exit 1
    fi
}

check_command "sops" "brew install sops (macOS) or download from https://github.com/getsops/sops/releases"
check_command "age" "brew install age (macOS) or download from https://github.com/FiloSottile/age/releases"

# Create local sops directory
SOPS_DIR="$HOME/.sops"
mkdir -p "$SOPS_DIR"

# Generate age key if not exists
AGE_KEY_FILE="$SOPS_DIR/age-key.txt"
if [ -f "$AGE_KEY_FILE" ]; then
    echo "Age key already exists at: $AGE_KEY_FILE"
else
    echo "Generating new age key..."
    age-keygen -o "$AGE_KEY_FILE" 2>&1 | tee "$SOPS_DIR/age-public-key.txt"
    chmod 600 "$AGE_KEY_FILE"
    echo "Age key generated at: $AGE_KEY_FILE"
fi

# Extract public key
PUBLIC_KEY=$(grep -o 'age1[a-z0-9]*' "$SOPS_DIR/age-public-key.txt" 2>/dev/null || grep 'public key:' "$AGE_KEY_FILE" | awk '{print $NF}')

echo ""
echo "=== Your age public key ==="
echo "$PUBLIC_KEY"
echo ""
echo "=== Next steps ==="
echo "1. Update .sops.yaml in this repo with your public key:"
echo "   age: $PUBLIC_KEY"
echo ""
echo "2. Set environment variable for SOPS to find your key:"
echo "   export SOPS_AGE_KEY_FILE=$AGE_KEY_FILE"
echo ""
echo "3. Add to your shell profile (~/.bashrc or ~/.zshrc):"
echo "   export SOPS_AGE_KEY_FILE=$AGE_KEY_FILE"
echo ""
echo "4. To encrypt a file:"
echo "   sops --encrypt secrets.yaml > secrets.enc.yaml"
echo ""
echo "5. To edit an encrypted file:"
echo "   sops environments/production/hieradata/secrets/common.yaml"
