#!/bin/bash
# Helper script to deploy Puppet code with r10k
# Usage: puppet-deploy [environment]

set -e

ENVIRONMENT="${1:-production}"

echo "Deploying Puppet environment: ${ENVIRONMENT}"

# Run r10k deploy
/opt/puppetlabs/puppet/bin/r10k deploy environment "${ENVIRONMENT}" -pv

# Generate types
/opt/puppetlabs/bin/puppet generate types --environment "${ENVIRONMENT}"

echo "Deployment complete for environment: ${ENVIRONMENT}"
