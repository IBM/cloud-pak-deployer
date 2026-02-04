#!/bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
ARCH=$(uname -m)
if [ "${ARCH}" == "amd64" ];then
  ARCH="x86_64"
fi
DEPLOYER_DIR=$(dirname ${SCRIPT_DIR})
WEBUI_DIR=${DEPLOYER_DIR}/deployer-web

echo "-------------------------------------------------------------------------------"
echo "Starting the Web UI in the container"
echo "-------------------------------------------------------------------------------"

export PATH=$PATH:${DEPLOYER_DIR}

cd ${WEBUI_DIR}

# If CONFIG_DIR was not set, set it to the default
if [ "${CONFIG_DIR}" == "" ];then
    export CONFIG_DIR="$HOME/cpd-config"
    echo "Default config directory set to $CONFIG_DIR"
    mkdir -p $CONFIG_DIR
fi

# If STATUS_DIR was not set, set it to the default
if [ "${STATUS_DIR}" == "" ];then
    export STATUS_DIR="$HOME/cpd-status"
    echo "Default status directory set to $STATUS_DIR"
    mkdir -p $STATUS_DIR
fi

# Clear the state directory
mkdir -p ${STATUS_DIR}/state
rm -rf ${STATUS_DIR}/state/*

echo "Starting NGINX backend service..."

if [[ "${ARCH}" == "x86_64" ]]; then
    nginx -s stop
elif [[ "${ARCH}" == "arm64" ]]; then
    nginx -s stop -p ${WEBUI_DIR} -c ${WEBUI_DIR}/nginx-mac.conf
else
    echo "Unsupported architecture: ${ARCH}"
    exit 1
fi

sleep 2

if [[ "${ARCH}" == "x86_64" ]]; then
    nginx
elif [[ "${ARCH}" == "arm64" ]]; then
    nginx -p ${WEBUI_DIR} -c ${WEBUI_DIR}/nginx-mac.conf
else
    echo "Unsupported architecture: ${ARCH}"
    exit 1
fi

echo "Starting Web UI"
echo "Logging level (CPD_WIZARD_LOG_LEVEL): ${CPD_WIZARD_LOG_LEVEL}"
python3 webapp.py

exit 0