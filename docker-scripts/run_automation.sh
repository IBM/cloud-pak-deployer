#!/bin/bash

env_vars="GIT_CONFIG_REPO_URL GIT_ACCESS_TOKEN CONTEXT_DIR IBM_CLOUD_API_KEY"

error=0
for env_var in $env_vars;do
    if [[ ! -v $env_var ]];then
        echo "Error: environment variable $env_var has not been set"
        error=1
    fi
done

if [[ error -ne 0 ]];then
    echo "Error running automation"
    exit 1
fi

#Disable asking for credentials when login fails.
export GIT_TERMINAL_PROMPT=0

export GIT_HOST=$(cut -d '/' -f3 <<<"${GIT_CONFIG_REPO_URL}")
echo "Using Git host: ${GIT_HOST}"

#Login to the GH cli to clone the config repo
echo "${GIT_ACCESS_TOKEN}" > /tmp/git_api_key.txt
gh auth login -h ${GIT_HOST} --with-token < /tmp/git_api_key.txt

if [ $? -ne 0 ]; then
  echo "GH cli login command failed..."
  echo "Exiting with exit code 1"
  echo ""
  rm -f /tmp/git_api_key.txt
  exit 1
fi

rm -f /tmp/git_api_key.txt

# Navigate to the /automation_config folder
cd /automation_config
# Clear any existing content from the CONF_FOLDER_PATH
rm -rf *

# Clone the config repository
export GIT_CONFIG_REPO_URL_WITH_TOKEN="https://iamapikey:${GIT_ACCESS_TOKEN}@${GIT_CONFIG_REPO_URL#https://}"
git clone ${GIT_CONFIG_REPO_URL_WITH_TOKEN} .

if [ $? -ne 0 ]; then
  echo "git clone ${GIT_CONFIG_REPO_URL_WITH_TOKEN} failed..."
  echo "Exiting with exit code 1"
  echo ""
  exit 1
fi

# Validate if the specified context directory exists
if [ -d "./${CONTEXT_DIR}" ]; then
    echo "Context directory ${CONTEXT_DIR} found."
else
    echo "Context directory ${CONTEXT_DIR} not found."
    echo "Exiting with exit code 1"
    echo ""
    exit 1
fi

# Validate if the configuration directory exists
CONFIG_DIR="/automation_config/${CONTEXT_DIR}/config"
if [ -d "${CONFIG_DIR}" ]; then
    echo "Configuration directory ${CONFIG_DIR} found."
else
    echo "Configuration directory ${CONFIG_DIR} not found."
    echo "Exiting with exit code 1"
    echo ""
    exit 1
fi

# Validate if the inventory directory exists
INV_DIR="/automation_config/${CONTEXT_DIR}/inventory"
if [ -d "${INV_DIR}" ]; then
    echo "Inventory directory ${INV_DIR} found."
else
    echo "Inventory directory ${INV_DIR} not found."
    echo "Exiting with exit code 1"
    echo ""
    exit 1
fi

echo ""
echo "Starting Automation script..."
echo ""

cd /automation_script

ansible-playbook -i ${INV_DIR}/inventory-acme-uat-dev.inv playbook-e2e.yml --extra-vars input_dir=${CONFIG_DIR} --extra-vars iaas_classic_username=${iaas_classic_username} --extra-vars iaas_classic_api_key=${iaas_classic_api_key} --extra-vars ibmcloud_api_key=${ibmcloud_api_key} --extra-vars vault_api_key=${vault_api_key} --extra-vars ibm_cp4d_entitlement_key=${ibm_cp4d_entitlement_key} "$@"  

