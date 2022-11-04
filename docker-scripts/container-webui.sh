#!/bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

echo "-------------------------------------------------------------------------------"
echo "Starting the Web UI in the container"
echo "-------------------------------------------------------------------------------"

export PS1='\[\e]0;\w\a\]\n[\#] \[\e[32m\u@Cloud Pak Deployer:\[\e[33m\]\w \e[m\$ ';
export PATH=$PATH:/cloud-pak-deployer

cd /cloud-pak-deployer/deployer-web
pip3 install -r requirements.txt > /tmp/pip_install.log

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

python3 webapp.py

exit 0