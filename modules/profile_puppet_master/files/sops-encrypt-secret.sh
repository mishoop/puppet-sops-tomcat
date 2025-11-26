#!/bin/bash
# Helper script to encrypt secrets with SOPS
# Usage: sops-encrypt-secret <input-file> [output-file]

set -e

INPUT_FILE="$1"
OUTPUT_FILE="${2:-${INPUT_FILE}}"

if [ -z "$INPUT_FILE" ]; then
    echo "Usage: sops-encrypt-secret <input-file> [output-file]"
    echo ""
    echo "Environment variables:"
    echo "  SOPS_AGE_RECIPIENTS - age public key(s) for encryption"
    echo ""
    exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file not found: $INPUT_FILE"
    exit 1
fi

# Check for age public key
AGE_PUBLIC_KEY_FILE="/etc/puppetlabs/puppet/sops/age-public-key.txt"
if [ -f "$AGE_PUBLIC_KEY_FILE" ] && [ -z "$SOPS_AGE_RECIPIENTS" ]; then
    export SOPS_AGE_RECIPIENTS=$(grep -o 'age1[a-z0-9]*' "$AGE_PUBLIC_KEY_FILE" | head -1)
fi

if [ -z "$SOPS_AGE_RECIPIENTS" ]; then
    echo "Error: No age recipient key found"
    echo "Set SOPS_AGE_RECIPIENTS or ensure $AGE_PUBLIC_KEY_FILE exists"
    exit 1
fi

echo "Encrypting $INPUT_FILE with age key: ${SOPS_AGE_RECIPIENTS:0:20}..."

if [ "$INPUT_FILE" = "$OUTPUT_FILE" ]; then
    /usr/local/bin/sops --encrypt --in-place "$INPUT_FILE"
else
    /usr/local/bin/sops --encrypt "$INPUT_FILE" > "$OUTPUT_FILE"
fi

echo "Encrypted successfully: $OUTPUT_FILE"
