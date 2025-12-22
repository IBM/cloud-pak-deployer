#!/bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

echo "-------------------------------------------------------------------------------"
echo "Entering Cloud Pak Deployer command line in a container."
echo 'Use the "exit" command to leave the container and return to the hosting server.'
echo "-------------------------------------------------------------------------------"

# export PS1='\[\e]0;\w\a\]\n[\#] \[\e[32m\u@Cloud Pak Deployer:\[\e[33m\]\w \e[m\$ ';
export PS1="[\#] \e[0;32m[\u@Cloud Pak Deployer: \W] \e[m "

# Get the public and private keys if existing
if grep -q ocp-ssh $STATUS_DIR/vault/* 2>&1;then
  echo "Getting SSH keys from vault ..."
  TEMP_DIR=$(mktemp -d)
  $SCRIPT_DIR/../cp-deploy.sh vault get -vs ocp-ssh-private-key -vsf $TEMP_DIR/id_rsa > /dev/null
  $SCRIPT_DIR/../cp-deploy.sh vault get -vs ocp-ssh-pub-key -vsf $TEMP_DIR/id_rsa.pub > /dev/null

  mkdir -p ~/.ssh
  chmod 700 ~/.ssh

  if [[ ! -z $(grep '[^[:space:]]' $TEMP_DIR/id_rsa) ]];then
    echo "Writing SSH keys to ~/.ssh..."
    rm -f ~/.ssh/id_rsa
    cp $TEMP_DIR/id_rsa ~/.ssh/id_rsa
    chmod 600 ~/.ssh/id_rsa
  fi

  if [[ ! -z $(grep '[^[:space:]]' $TEMP_DIR/id_rsa.pub) ]];then
    rm -f ~/.ssh/id_rsa.pub
    cp $TEMP_DIR/id_rsa ~/.ssh/id_rsa.pub
    chmod 600 ~/.ssh/id_rsa.pub
  fi
fi

if [ -e $STATUS_DIR/openshift/kubeconfig ];then
  # Copy the kubeconfig file to the one in use by olm utils
  cp -f $STATUS_DIR/openshift/kubeconfig /opt/ansible/.kubeconfig
  chmod 777 /opt/ansible/.kubeconfig
  # Show the current context
  oc_context=$(oc config current-context)
  oc_api_endpoint=$(oc whoami --show-server)
  oc_console_endpoint=$(oc whoami --show-console)
  echo "Current OpenShift context : $oc_context"
  echo "Current OpenShift API endpoint: $oc_api_endpoint"
  echo "Current OpenShift console URL: $oc_console_endpoint"
else
  echo "No existing OpenShift configuration found, you will need to login to OpenShift first."
fi

OLM_UTILS_IMAGE_PREFIX=$(cat $(ls -1 /cloud-pak-deployer/.version-info/olm-utils-v*.txt | tail -1) | cut -d: -f1)
OLM_UTILS_IMAGE_DIGEST=$(jq -r '.manifests[0].digest' $(ls -1 /cloud-pak-deployer/.version-info/olm-utils-v*manifest.json | tail -1))
export OLM_UTILS_IMAGE="${OLM_UTILS_IMAGE_PREFIX}@${OLM_UTILS_IMAGE_DIGEST}"
echo "Environment variable OLM_UTILS_IMAGE set to ${OLM_UTILS_IMAGE}"

echo

export PATH=${PATH}:/cloud-pak-deployer
cd /cloud-pak-deployer

/bin/bash

exit 0