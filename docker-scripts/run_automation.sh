#!/bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

error=0

# Check mandatory parameters
if [ ! -v IBM_CLOUD_API_KEY ];then
    echo "Error: environment variable IBM_CLOUD_API_KEY has not been set and is required"
    error=1
fi

if [ -v GIT_REPO_URL ];then
    if [ ! -v GIT_ACCESS_TOKEN ];then
        echo "Error: environment variable GIT_ACCESS_TOKEN has not been set and is required"
        error=1
    fi
    if [ ! -v GIT_REPO_DIR ];then
        echo "Error: environment variable GIT_REPO_DIR has not been set and is required"
        error=1
    fi
fi

if [ ! -v GIT_REPO_URL ] && [ ! -v CONFIG_DIR ];then
    echo "Error: either environment variable GIT_REPO_URL or CONFIG_DIR must be specified"
    error=1
fi

if [[ error -ne 0 ]];then
    echo "Error running automation"
    exit 1
fi

# Handle configuration on GitHub
if [ -v GIT_REPO_URL ];then
    GIT_DIR=/tmp/automation_config
    mkdir -p ${GIT_DIR}

    #Disable asking for credentials when login fails.
    export GIT_TERMINAL_PROMPT=0

    export GIT_HOST=$(cut -d '/' -f3 <<<"${GIT_REPO_URL}")
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

    # Clear any existing content from the CONF_FOLDER_PATH
    rm -rf ${GIT_DIR}/*

    # Clone the config repository
    export GIT_REPO_URL_WITH_TOKEN="https://iamapikey:${GIT_ACCESS_TOKEN}@${GIT_REPO_URL#https://}"
    pushd ${GIT_DIR}
    git clone ${GIT_REPO_URL_WITH_TOKEN} .
    popd

    if [ $? -ne 0 ]; then
        echo "git clone ${GIT_REPO_URL_WITH_TOKEN} failed..."
        echo "Exiting with exit code 1"
        echo ""
        exit 1
    fi

    CONFIG_DIR=${GIT_DIR}/${GIT_REPO_DIR}

    # Validate if the specified context directory exists
    if [ ! -d "${CONFIG_DIR}" ]; then
        echo "Context directory ${GIT_REPO_DIR} not found."
        echo "Exiting with exit code 1"
        echo ""
        exit 1
    fi

    # Validate if the configuration directory exists
    CONF_DIR="${CONFIG_DIR}/config"
    if [ ! -d "${CONF_DIR}" ]; then
        echo "config directory not found in context directory ${GIT_REPO_DIR}."
        echo "Exiting with exit code 1"
        echo ""
        exit 1
    fi

    # Validate if the inventory directory exists
    INV_DIR="${CONFIG_DIR}/inventory"
    if [ ! -d "${INV_DIR}" ]; then
        echo "inventroy directory not found in context directory ${GIT_REPO_DIR}."
        echo "Exiting with exit code 1"
        echo ""
        exit 1
    fi
else
    # Validate if the configuration directory exists
    CONF_DIR="${CONFIG_DIR}/config"
    if [ ! -d "${CONF_DIR}" ]; then
        echo "config directory not found in directory ${CONFIG_DIR}."
        echo "Exiting with exit code 1"
        echo ""
        exit 1
    fi

    # Validate if the inventory directory exists
    INV_DIR="${CONFIG_DIR}/inventory"
    if [ ! -d "${INV_DIR}" ]; then
        echo "inventroy directory not found in directory ${CONFIG_DIR}."
        echo "Exiting with exit code 1"
        echo ""
        exit 1
    fi
fi

echo ""
echo "Starting Automation script..."
echo ""
cd ${SCRIPT_DIR}/..

ansible-playbook \
    -i ${INV_DIR} \
    playbook-e2e.yml \
    --extra-vars config_dir=${CONFIG_DIR} \
    --extra-vars status_dir=${STATUS_DIR} \
    --extra-vars ibmcloud_api_key=${IBM_CLOUD_API_KEY} \
    --extra-vars ibm_cp4d_entitlement_key=${ibm_cp4d_entitlement_key} \
    "$@"  


