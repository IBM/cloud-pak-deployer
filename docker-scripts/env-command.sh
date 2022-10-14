#!/bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

echo "-------------------------------------------------------------------------------"
echo "Entering Cloud Pak Deployer command line in a container."
echo 'Use the "exit" command to leave the container and return to the hosting server.'
echo "-------------------------------------------------------------------------------"

export PS1='\[\e]0;\w\a\]\n[\#] \[\e[32m\u@Cloud Pak Deployer:\[\e[33m\]\w \e[m\$ ';

if [ -z "$cloud_platform" ]; then
  echo "cloud_platform is not defined."
  exit 1
fi

#Create the ssh key pair
if [ -f "$STATUS_DIR/vault/$cloud_platform" ]; then
  ocp_ssh_private_key=$(awk -F "-key=" '/ocp-ssh-private/ {print $2}' $STATUS_DIR/vault/$cloud_platform)
  ocp_ssh_pub_key=$(awk -F "-key=" '/ocp-ssh-pub/ {print $2}' $STATUS_DIR/vault/$cloud_platform)

  if [ ! -z "$ocp_ssh_private_key" ] && [ ! -z "$ocp_ssh_pub_key" ];then
  ssh_key_pair_folder='/root/.ssh'
  if [ ! -d "$ssh_key_pair_folder" ]; then
    mkdir -p "$ssh_key_pair_folder"
  fi
  echo "Create the SSH key-pair id_rsa.pub and id_rsa files in the folder root/.ssh/"
  echo $ocp_ssh_private_key |base64 -d > "$ssh_key_pair_folder"/id_rsa
  echo $ocp_ssh_pub_key |base64 -d > "$ssh_key_pair_folder"/id_rsa.pub
  #fix the issue "invalid format"
  sed -i '$a\\r' "$ssh_key_pair_folder"/id_rsa
  chmod 600 "$ssh_key_pair_folder"/id_rsa
  chmod 600 "$ssh_key_pair_folder"/id_rsa.pub
fi

fi




oc_zip=$(find $STATUS_DIR/downloads/ -name "openshift-client*" | tail -1)
if [ "$oc_zip" != "" ];then
  echo "Installing OpenShift client"
  tar xvzf $oc_zip -C /usr/local/bin --exclude='README.md' > /dev/null
  if [ -e $STATUS_DIR/openshift/kubeconfig ];then
    # Use a copy of the kubeconfig file so that the command line doesn't conflict with an active deployer
    cp -f $STATUS_DIR/openshift/kubeconfig /tmp/kubeconfig
    export KUBECONFIG=/tmp/kubeconfig
    # Show the current context
    oc_context=$(oc config current-context)
    echo "Current OpenShift context: $oc_context"
  else
    echo "No existing OpenShift configuration found, you will need to login to OpenShift first."
  fi
else
  echo "Warning: OpenShift client not found under $STATUS_DIR/downloads, oc command will not be available."
fi

/bin/bash

exit 0