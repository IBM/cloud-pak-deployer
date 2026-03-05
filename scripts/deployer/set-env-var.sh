#!/bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

# Set OLM_UTILS_IMAGE environment variable, needed for most cpd-cli commands
OLM_UTILS_IMAGE_PREFIX=$(cat $(ls -1 ${SCRIPT_DIR}/../../.version-info/olm-utils-v*.txt | tail -1) | cut -d: -f1)
OLM_UTILS_IMAGE_DIGEST=$(jq -r '.manifests[0].digest' $(ls -1 ${SCRIPT_DIR}/../../.version-info/olm-utils-v*manifest.json | tail -1))
export OLM_UTILS_IMAGE="${OLM_UTILS_IMAGE_PREFIX}@${OLM_UTILS_IMAGE_DIGEST}"
echo "Environment variable OLM_UTILS_IMAGE set to ${OLM_UTILS_IMAGE}"