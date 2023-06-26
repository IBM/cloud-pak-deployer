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

# Generate kubelet config
echo "Generating kubelet config"
first_compute=$(oc get no --no-headers -l node-role.kubernetes.io/worker -o custom-columns='name:.metadata.name' | head -1)
oc debug no/${first_compute} --to-namespace kube-system \
    -- cat /host/etc/kubernetes/kubelet.conf > /tmp/cp4d-kubelet.conf
sed -i "/# BEGIN ANSIBLE MANAGED BLOCK/,/# END ANSIBLE MANAGED BLOCK/d" /tmp/cp4d-kubelet.conf
cat << EOF >> /tmp/cp4d-kubelet.conf
# BEGIN ANSIBLE MANAGED BLOCK
allowedUnsafeSysctls:
- "kernel.msg*"
- "kernel.shm*"
- "kernel.sem"
# END ANSIBLE MANAGED BLOCK
EOF
oc set data -n kube-system cm/cloud-pak-node-fix-config --from-file=/tmp/cp4d-kubelet.conf

# Generate crio config
echo "Generating crio config"
oc debug no/${first_compute} --to-namespace kube-system \
    -- cat /host/etc/crio/crio.conf > /tmp/cp4d-crio.conf
sed -i "s/pids_limit.*/pids_limit = 12288/" /tmp/cp4d-crio.conf
oc set data -n kube-system cm/cloud-pak-node-fix-config --from-file=/tmp/cp4d-crio.conf

# Generate tuned
echo "Generating Tuned config"
cat ${AUTOMATION_ROLES_DIR}/cp4d/cp4d-ocp-tuned/templates/cp4d-tuned.j2 | sed "s/{{ cp4d_tuned_name }}/cp4d-ipc/" > /tmp/cp4d-tuned.yaml
oc apply -f /tmp/cp4d-tuned.yaml

# Populate configmap with scripts
echo "Writing fix scripts to config map"
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