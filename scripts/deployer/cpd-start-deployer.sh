#!/bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

command_usage() {
  echo
  echo "Usage: $0 [OPTIONS]"
  echo
  echo "OPTIONS:"
  echo "  --debug-only         Run debug job only, not the deployer job"
  exit 1
}

# Check that subcommand is valid
PARAMS=""
while (( "$#" )); do
  case "$1" in
  --debug-only)
    export DEBUG_ONLY=true
    shift 1
    ;;
  *) 
    echo "Invalid option."
    command_usage 1
    shift 1
    ;;
  esac
done

# Check if we can connect to the OpenShift cluster
oc cluster-info > /dev/null 2>&1
if [ $? -ne 0 ];then
    echo "Could not connect to OpenShift, exiting."
    exit 1
fi

# Check if the cloud-pak-deployer-config configmap exists
if ! $(oc get cm cloud-pak-deployer-config > /dev/null);then
    echo "ConfigMap cloud-pak-deployer-config not found in the current project. Please create before starting deployer. Exiting."
    exit 1
fi

# Determine if the PVC must be created
if ! $(oc get pvc cloud-pak-deployer-status > /dev/null 2>&1 );then
    echo "Determining storage class for cloud-pak-deployer-status PVC..."
    if oc get sc managed-nfs-storage > /dev/null 2>&1;then
        export DEPLOYER_SC=managed-nfs-storage
    elif oc get sc ocs-storagecluster-cephfs > /dev/null 2>&1;then
        export DEPLOYER_SC=ocs-storagecluster-cephfs
    elif oc get sc ocs-external-storagecluster-cephfs > /dev/null 2>&1;then
        export DEPLOYER_SC=ocs-external-storagecluster-cephfs
    elif oc get sc ibmc-file-gold-gid > /dev/null 2>&1;then
        export DEPLOYER_SC=ibmc-file-gold-gid
    else
        echo "No supported storage class found for the deployer job, exiting."
        exit 1
    fi
    echo "Creating PVC cloud-pak-deployer-status..."
    oc process -f ${SCRIPT_DIR}/assets/cloud-pak-deployer-status-pvc.yaml -p DEPLOYER_SC=${DEPLOYER_SC} | oc apply -f -
fi

# Check if Cloud Pak Deployer job is active
if ! "${DEBUG_ONLY}";then
  deployer_status=$(oc get job cloud-pak-deployer -o jsonpath='{.status.active}' 2>/dev/null)
  if [ "${deployer_status}" == "1" ];then
      echo "Cloud Pak Deployer job is still active, exiting."
      exit 1
  fi
fi

# Delete finished cloud-pak-deployer-start pods
oc delete pods --field-selector=status.phase==Succeeded -l app=cloud-pak-deployer-start

# Delete finished Cloud Pak Deployer jobs
oc delete job cloud-pak-deployer --ignore-not-found
oc delete job cloud-pak-deployer-debug --ignore-not-found

# Determine image
IMAGE=$(oc get pod ${HOSTNAME} -o=jsonpath='{.spec.containers[0].image}')

# Start Cloud Pak Deployer jobs
if ! "${DEBUG_ONLY}";then
  echo "Starting the deployer job..."
  oc process -f ${SCRIPT_DIR}/assets/cloud-pak-deployer-job.yaml -p IMAGE=${IMAGE} | oc apply -f -
fi

# Start a debug job (sleep infinity) so that we can easily get access to the deployer logs
echo "Starting the deployer debug job..."
oc process -f ${SCRIPT_DIR}/assets/cloud-pak-deployer-debug-job.yaml -p IMAGE=${IMAGE} | oc apply -f -