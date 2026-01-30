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

<<<<<<< HEAD
check_configmap_exists() {
  local configmap_name=$1
  if ! oc get cm "${configmap_name}" > /dev/null 2>&1; then
    return 1
  fi
  return 0
}

=======
>>>>>>> main
# Check that subcommand is valid
PARAMS=""
while (( "$#" )); do
  case "$1" in
  --debug-only)
    export DEBUG_ONLY=true
    shift 1
    ;;
<<<<<<< HEAD
  --wizard)
    export CPD_WIZARD=true
    shift 1
    ;;

=======
>>>>>>> main
  *) 
    echo "Invalid option."
    command_usage 1
    shift 1
    ;;
  esac
done

echo "Environment variables:"
env

# Check if we can connect to the OpenShift cluster
oc cluster-info > /dev/null 2>&1
if [ $? -ne 0 ];then
    echo "Could not connect to OpenShift, exiting."
    exit 1
fi

<<<<<<< HEAD
#
# General steps
#
=======
# Check if the cloud-pak-deployer-config configmap exists
if ! $(oc get cm cloud-pak-deployer-config > /dev/null);then
    echo "ConfigMap cloud-pak-deployer-config not found in the current project. Please create before starting deployer. Exiting."
    exit 1
fi

>>>>>>> main
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
    elif oc get sc ibmc-vpc-file-1000-iops > /dev/null 2>&1;then
        export DEPLOYER_SC=ibmc-vpc-file-1000-iops
    else
        echo "No supported storage class found for the deployer job, exiting."
        exit 1
    fi
    echo "Creating PVC cloud-pak-deployer-status..."
    oc process -f ${SCRIPT_DIR}/assets/cloud-pak-deployer-status-pvc.yaml -p DEPLOYER_SC=${DEPLOYER_SC} | oc apply -f -
fi

<<<<<<< HEAD
# Delete finished cloud-pak-deployer-start pods
oc delete pods --field-selector=status.phase==Succeeded -l app=cloud-pak-deployer-start

# Determine image
IMAGE=$(oc get pod ${HOSTNAME} -o=jsonpath='{.spec.containers[0].image}')
echo "Image used: ${IMAGE}"

if [ "$CPD_DEBUG" ]; then
  # Check if the cloud-pak-deployer-config configmap exists
  if ! check_configmap_exists "cloud-pak-deployer-config"; then
      echo "ConfigMap cloud-pak-deployer-config not found in the current project. Please create before starting deployer. Exiting."
      exit 1
  fi

  # Delete finished Cloud Pak Deployer debug jobs
  oc delete job cloud-pak-deployer-debug --ignore-not-found

  echo "Starting the deployer debug job..."
  oc process -f ${SCRIPT_DIR}/assets/cloud-pak-deployer-debug-job.yaml -p IMAGE=${IMAGE} | oc apply -f -

elif [ "$CPD_WIZARD" ]; then

  export LC_ALL=C
  oc create secret generic cloud-pak-deployer-wizard-proxy \
    --from-literal=session_secret=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c43)
  unset LC_ALL

  oc annotate serviceaccount cloud-pak-deployer-sa \
    serviceaccounts.openshift.io/oauth-redirectreference.wizard='{"kind":"OAuthRedirectReference","apiVersion":"v1","reference":{"kind":"Route","name":"wizard"}}'

  # Delete finished Cloud Pak Deployer wizard
  oc delete deployment cloud-pak-deployer-wizard --ignore-not-found

  echo "Starting the deployer wizard..."
  oc process -f ${SCRIPT_DIR}/assets/cloud-pak-deployer-wizard.yaml -p IMAGE=${IMAGE} | oc apply -f -

else
  # Check if the cloud-pak-deployer-config configmap exists
  if ! check_configmap_exists "cloud-pak-deployer-config"; then
      echo "ConfigMap cloud-pak-deployer-config not found in the current project. Please create before starting deployer. Exiting."
      exit 1
  fi

  # Check if Cloud Pak Deployer job is active
  if ! "${DEBUG_ONLY}";then
    deployer_status=$(oc get job cloud-pak-deployer -o jsonpath='{.status.active}' 2>/dev/null)
    if [ "${deployer_status}" == "1" ];then
        echo "Cloud Pak Deployer job is still active, exiting."
        exit 1
    fi
  fi

  # Delete finished Cloud Pak Deployer jobs
  oc delete job cloud-pak-deployer --ignore-not-found
  oc delete job cloud-pak-deployer-debug --ignore-not-found

  echo "Starting the deployer job..."
  oc process -f ${SCRIPT_DIR}/assets/cloud-pak-deployer-job.yaml -p IMAGE=${IMAGE} | oc apply -f -

  echo "Starting the deployer debug job..."
  oc process -f ${SCRIPT_DIR}/assets/cloud-pak-deployer-debug-job.yaml -p IMAGE=${IMAGE} | oc apply -f -

fi

exit 0
=======
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
>>>>>>> main
