#!/bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

echo "-------------------------------------------------------------------------------"
echo "Entering Cloud Pak Deployer command line in a container."
echo 'Use the "exit" command to leave the container and return to the hosting server.'
echo "-------------------------------------------------------------------------------"

export PS1="\e[0;30m\e[106m[\u@Cloud Pak Deployer Container \W]\e[m\$ "
export PATH=$PATH:/cloud-pak-deployer

/bin/bash

exit 0