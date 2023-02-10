#!/bin/bash

#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#         ________  __  ___     ___    ________       
#        /  _/ __ )/  |/  /    /   |  /  _/ __ \____  _____
#        / // __  / /|_/ /    / /| |  / // / / / __ \/ ___/
#      _/ // /_/ / /  / /    / ___ |_/ // /_/ / /_/ (__  ) 
#     /___/_____/_/  /_/    /_/  |_/___/\____/ .___/____/  
#                                           /_/
#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------------------------------------------------"
#  Delete Instana Installation and Backend
#
#  CloudPak for Watson AIOps
#
#  ©2022 nikh@ch.ibm.com
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"
# ---------------------------------------------------------------------------------------------------------------------------------------------------"


if [ -x "$(command -v kubectl-instana)" ]; then
    echo "Kubectl Instana Plugin already installed"
else
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    echo "Installing Kubectl Instana Plugin for $OS"
    if [ "${OS}" == "darwin" ]; then
          wget https://self-hosted.instana.io/kubectl/kubectl-instana-darwin_amd64-release-235-3.tar.gz
          tar xfvz kubectl-instana-darwin_amd64-release-235-3.tar.gz
          sudo mv kubectl-instana /usr/local/bin/kubectl-instana
          rm kubectl-instana-darwin_amd64-release-235-3.tar.gz
    else
        echo "deb [arch=amd64] https://self-hosted.instana.io/apt generic main" > /etc/apt/sources.list.d/instana-product.list
        wget -qO - "https://self-hosted.instana.io/signing_key.gpg" | apt-key add -
        apt-get update
        apt-get install instana-kubectl
    fi
fi

oc delete agents.instana.io -n instana-agent instana-agent
oc delete subscription -n openshift-operators instana-agent
oc delete ns instana-agent

  #delete instana based on flag
oc -n instana-units delete unit --all
oc delete ns instana-units 
oc -n instana-core delete core --all 
oc delete ns instana-core 
oc delete ns instana-datastores

#If the `instana-core` project gets stuck deleting, it's probably waiting on the `Core` resource which still has a finalizer on it. You can remove that with the below command

#oc -n instana-core patch core instana-core -p '{"metadata":{"finalizers":null}}' --type=merge
#oc -n instana-units patch unit aiops-dev -p '{"metadata":{"finalizers":null}}' --type=merge
#oc -n instana-units patch unit aiops-prod  -p '{"metadata":{"finalizers":null}}' --type=merge
oc project instana-operator
kubectl instana operator template --output-dir=instana-operator-resources
oc -n instana-operator delete -f ./instana-operator-resources/ --namespace=instana-operator
oc delete ns instana-operator
rm -rf ./instana-operator-resources
echo "Instana removed from OpenShift successfully!"
exit 0;
