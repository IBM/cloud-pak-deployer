#!/bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

# This scripts applies the cluster settings that would normally be applied using the deployer
# on ROKS and Satellite clusters.

# Check if we can connect to the OpenShift cluster
oc cluster-info > /dev/null 2>&1
if [ $? -ne 0 ];then
    echo "Could not connect to OpenShift, exiting."
    exit 1
fi

# Check if the Machine Config Operator has been installed
if [ $(oc get mcp --no-headers 2>/dev/null | wc -l) -ne 0 ];then
    echo "It is not allowed to run this script on an OpenShift cluster with the Machine Config Operator installed"
    exit 1
fi

AUTOMATION_ROLES_DIR="${SCRIPT_DIR}/../../automation-roles/50-install-cloud-pak"

if [[ "${CPD_PRIVATE_REGISTRY}" != "" ]] && [[ "${CPD_PRIVATE_REGISTRY_CREDS}" == "" ]]; then
    echo "When private registry CPD_PRIVATE_REGISTRY environment variable is set, CPD_PRIVATE_REGISTRY_CREDS must also be set"
    exit 1
fi
if [[ "${CPD_PRIVATE_REGISTRY}" == "" ]] && [[ "${CP_ENTITLEMENT_KEY}" == "" ]]; then
    echo "Either CPD_PRIVATE_REGISTRY or CP_ENTITLEMENT_KEY variables must be set"
    exit 1
fi

# Create config map and secret
echo "Creating ConfigMaps and secret"
oc delete cm -n kube-system cloud-pak-node-fix-scripts --ignore-not-found
oc create cm -n kube-system cloud-pak-node-fix-scripts
oc delete cm -n kube-system cloud-pak-node-fix-config --ignore-not-found
oc create cm -n kube-system cloud-pak-node-fix-config
oc delete secret -n kube-system cloud-pak-node-fix-secrets --ignore-not-found
oc create secret generic -n kube-system cloud-pak-node-fix-secrets

# Set global pull secret
echo "Setting global pull secret"
if [[ "${CPD_PRIVATE_REGISTRY}" != "" ]]; then
    REGISTRY=${CPD_PRIVATE_REGISTRY}
    REGISTRY_CREDS=$(echo -n ${CPD_PRIVATE_REGISTRY_CREDS} | base64 -w0)
else
    REGISTRY="cp.icr.io"
    REGISTRY_CREDS=$(echo -n "cp:${CP_ENTITLEMENT_KEY}" | base64 -w0)
fi

oc extract secret/pull-secret -n openshift-config --confirm --to=/tmp
cat /tmp/.dockerconfigjson | \
    jq --arg registry "${REGISTRY}" \
    --arg pull_secret $(echo -n "${REGISTRY_CREDS}") \
    '.auths += {($registry): {"auth": $pull_secret, "email": "not-used"}}' \
    > /tmp/newdockerconfigjson
oc set data secret/pull-secret -n openshift-config \
    --from-file=.dockerconfigjson=/tmp/newdockerconfigjson
oc set data -n kube-system secret/cloud-pak-node-fix-secrets \
    --from-file=newdockerconfigjson=/tmp/newdockerconfigjson

# Create ImageContentSourcePolicy
if [[ "${CPD_PRIVATE_REGISTRY}" != "" ]]; then
    echo "Private registry specified, creating ImageContentSourcePolicy for registry ${CPD_PRIVATE_REGISTRY}"
    cp ${AUTOMATION_ROLES_DIR}/cp-ocp-icsp/templates/cloud-pak-icsp-registries-conf.j2 /tmp/cloud-pak-icsp-registries.conf
    sed -i "s#{{ private_registry_url_namespace }}#${CPD_PRIVATE_REGISTRY}#g" /tmp/cloud-pak-icsp-registries.conf
    oc set data cm/cloud-pak-node-fix-config -n kube-system \
      --from-file=/tmp/cloud-pak-icsp-registries.conf
fi

# Generate tuned
echo "Generating Tuned config"
cat ${AUTOMATION_ROLES_DIR}/cp4d/cp4d-ocp-tuned/templates/cp4d-tuned.j2 | sed "s/{{ cp4d_tuned_name }}/cp4d-ipc/" > /tmp/cp4d-tuned.yaml
oc apply -f /tmp/cp4d-tuned.yaml

# Populate configmap with scripts
echo "Writing fix scripts to config map"
oc set data -n kube-system cm/cloud-pak-node-fix-scripts \
    --from-file=cp4d-apply-kubelet-config.sh=${AUTOMATION_ROLES_DIR}/cp4d/cp4d-ocp-kubelet-config/templates/cp4d-apply-kubelet-config.j2
oc set data -n kube-system cm/cloud-pak-node-fix-scripts \
    --from-file=cloud-pak-node-fix.sh=${AUTOMATION_ROLES_DIR}/cp-ocp-mco-resume/templates/cloud-pak-node-fix.j2
oc set data -n kube-system cm/cloud-pak-node-fix-scripts \
    --from-file=cloud-pak-node-fix-timer.sh=${AUTOMATION_ROLES_DIR}/cp-ocp-mco-resume/templates/cloud-pak-node-fix-timer.j2

# Create service account
echo "Creating service account for DaemonSet"
oc apply -f ${AUTOMATION_ROLES_DIR}/cp-ocp-mco-resume/templates/cloud-pak-node-fix-sa.j2
oc adm policy add-scc-to-user -n kube-system -z cloud-pak-crontab-sa privileged

# Recreate DaemonSet
echo "Recreate DaemonSet"
oc delete ds -n kube-system cloud-pak-crontab-ds --ignore-not-found
cat ${AUTOMATION_ROLES_DIR}/cp-ocp-mco-resume/templates/cloud-pak-node-fix-ds.j2 | sed "s/{{ cpd_ds_image | default('//" | sed "s/') }}//" > /tmp/cloud-pak-node-fix-ds.j2
oc apply -f /tmp/cloud-pak-node-fix-ds.j2

# Show pods
echo "Showing running DaemonSet pods"
oc get po -n kube-system -l name=cloud-pak-crontab-ds

# Wait 5 seconds
echo "Waiting for 5 seconds for pods to start"
sleep 5

# Show pods
echo
echo "Showing running DaemonSet pods"
oc get po -n kube-system -l name=cloud-pak-crontab-ds