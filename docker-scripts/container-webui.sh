#!/bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
ARCH=$(uname -m)
if [ "${ARCH}" == "amd64" ];then
  ARCH="x86_64"
fi
<<<<<<< HEAD
DEPLOYER_DIR=$(dirname ${SCRIPT_DIR})
WEBUI_DIR=${DEPLOYER_DIR}/deployer-web
=======
>>>>>>> main

echo "-------------------------------------------------------------------------------"
echo "Starting the Web UI in the container"
echo "-------------------------------------------------------------------------------"

export PATH=$PATH:${DEPLOYER_DIR}

<<<<<<< HEAD
cd ${WEBUI_DIR}
=======
cd /cloud-pak-deployer/deployer-web
>>>>>>> main

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

<<<<<<< HEAD
=======
echo "Check if OpenShift client is already in ${STATUS_DIR}/downloads folder..."
oc_tar=`ls -1 ${STATUS_DIR}/downloads/openshift-client-linux.tar.gz-* 2>/dev/null | tail -1`
if [ "$oc_tar" == "" ];then
    echo "Downloading OpenShift client..."
    mkdir -p ${STATUS_DIR}/downloads
    curl -s -L -o ${STATUS_DIR}/downloads/openshift-client-linux.tar.gz-stable https://mirror.openshift.com/pub/openshift-v4/${ARCH}/clients/ocp/stable/openshift-client-linux-${ARCH}.tar.gz
    oc_tar=${STATUS_DIR}/downloads/openshift-client-linux.tar.gz-stable
fi

echo "Unpacking OpenShift client from ${oc_tar}..."
tar xzf ${oc_tar} -C /usr/local/bin/

>>>>>>> main
# Clear the state directory
mkdir -p ${STATUS_DIR}/state
rm -rf ${STATUS_DIR}/state/*

<<<<<<< HEAD
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
=======
echo "Starting Deployer web UI and backend service..."
nginx
>>>>>>> main
python3 webapp.py

exit 0