#!/bin/bash
# Initialize secret files from examples
# This script creates the actual secret files from .example templates

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SECRETS_DIR="$REPO_ROOT/environments/production/hieradata/secrets"

echo "=== Initializing Secret Files ==="

# Check if SOPS_AGE_RECIPIENTS is set
if [ -z "$SOPS_AGE_RECIPIENTS" ]; then
    echo "Warning: SOPS_AGE_RECIPIENTS not set"
    echo "Files will be created but not encrypted"
    echo "Set SOPS_AGE_RECIPIENTS to your age public key to enable encryption"
    ENCRYPT=false
else
    ENCRYPT=true
    echo "Will encrypt with age key: ${SOPS_AGE_RECIPIENTS:0:25}..."
fi

# Process each .example file
find "$SECRETS_DIR" -name "*.yaml.example" | while read example_file; do
    target_file="${example_file%.example}"

    if [ -f "$target_file" ]; then
        echo "Skipping (exists): $target_file"
    else
        echo "Creating: $target_file"
        cp "$example_file" "$target_file"

        if [ "$ENCRYPT" = true ]; then
            echo "Encrypting: $target_file"
            sops --encrypt --in-place "$target_file"
        fi
    fi
done

echo ""
echo "=== Done ==="
echo "Secret files created in: $SECRETS_DIR"
if [ "$ENCRYPT" = false ]; then
    echo ""
    echo "WARNING: Files are NOT encrypted!"
    echo "Run 'sops --encrypt --in-place <file>' to encrypt each file"
fi
