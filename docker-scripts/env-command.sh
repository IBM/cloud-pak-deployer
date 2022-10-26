#!/bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

echo "-------------------------------------------------------------------------------"
echo "Entering Cloud Pak Deployer command line in a container."
echo 'Use the "exit" command to leave the container and return to the hosting server.'
echo "-------------------------------------------------------------------------------"

export PS1='\[\e]0;\w\a\]\n[\#] \[\e[32m\u@Cloud Pak Deployer:\[\e[33m\]\w \e[m\$ ';

# 0 - not exist; 1 - exists
ocp_ssh_private_key_exists=$($SCRIPT_DIR/../cp-deploy.sh vault list |grep "ocp-ssh-private-key" |wc -l)
ocp_ssh_pub_key_exists=$($SCRIPT_DIR/../cp-deploy.sh vault list |grep "ocp-ssh-pub-key" |wc -l)

#Create the ssh key pair
if [ "$ocp_ssh_private_key_exists" == 1 ] && [ "$ocp_ssh_pub_key_exists" == 1 ]; then

  ssh_key_pair_folder='/root/.ssh' 
  echo "Create the SSH key-pair id_rsa.pub and id_rsa files in the folder $ssh_key_pair_folder"      
  if [ ! -d "$ssh_key_pair_folder" ]; then
    mkdir -p "$ssh_key_pair_folder"
  fi

  # Write private key
  $SCRIPT_DIR/../cp-deploy.sh vault get -e ANSIBLE_STANDARD_OUTPUT=false -vs "ocp-ssh-private-key" -vsf "$ssh_key_pair_folder/id_rsa"
  if [[ "$?" -ne 0 ]]; then
    echo "Failed to create private key file: $ssh_key_pair_folder/id_rsa"
  else
    chmod 400 "$ssh_key_pair_folder"/id_rsa
  fi 
  # Write public key
  $SCRIPT_DIR/../cp-deploy.sh vault get -e ANSIBLE_STANDARD_OUTPUT=false -vs "ocp-ssh-pub-key" -vsf "$ssh_key_pair_folder/id_rsa.pub"
  if [[ "$?" -ne 0 ]]; then
    echo "Failed to create public key file: $ssh_key_pair_folder/id_rsa.pub"
  else
    chmod 400 "$ssh_key_pair_folder"/id_rsa.pub
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