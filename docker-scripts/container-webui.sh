#!/bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
ARCH=$(uname -m)
if [ "${ARCH}" == "amd64" ];then
  ARCH="x86_64"
fi

echo "-------------------------------------------------------------------------------"
echo "Starting the Web UI in the container"
echo "-------------------------------------------------------------------------------"

export PS1='\[\e]0;\w\a\]\n[\#] \[\e[32m\u@Cloud Pak Deployer:\[\e[33m\]\w \e[m\$ ';
export PATH=$PATH:/cloud-pak-deployer

cd /cloud-pak-deployer/deployer-web

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

# Clear the state directory
mkdir -p ${STATUS_DIR}/state
rm -rf ${STATUS_DIR}/state/*

echo "Starting Deployer web UI and backend service..."
nginx
python3 webapp.py

exit 0