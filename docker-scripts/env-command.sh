#!/bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

echo "-------------------------------------------------------------------------------"
echo "Entering Cloud Pak Deployer command line in a container."
echo 'Use the "exit" command to leave the container and return to the hosting server.'
echo "-------------------------------------------------------------------------------"

export PS1='\[\e]0;\w\a\]\n[\#] \[\e[32m\u@Cloud Pak Deployer:\[\e[33m\]\w \e[m\$ ';

# Get the public and private keys if existing
echo "Getting SSH keys from vault, if existing..."
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

oc_zip=$(find $STATUS_DIR/downloads/ -name "openshift-client*" | tail -1)
if [ "$oc_zip" != "" ];then
  echo "Installing OpenShift client..."
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