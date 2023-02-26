#!/bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

get_logtime() {
  echo $(date "+%Y-%m-%d %H:%M:%S")
}

log() {
  LOG_TIME=$(get_logtime)
  printf "[${LOG_TIME}] ${1}\n"
}

CP4D_PROJECT=$1
if [ -z "${CP4D_PROJECT}" ];then
    echo "Usage: $0 <cp4d-project>"
    exit 1
fi

# Ask for final confirmation to delete the CP4D instance
if [ -z "${CPD_CONFIRM_DELETE}" ];then
    read -p "Are you sure you want to delete CP4D instance ${CP4D_PROJECT} and Cloud Pak Foundational Services (y/N)? " -r
    case "${REPLY}" in 
    y|Y)
    ;;
    * )
    exit 99
    ;;
    esac
fi

# Create temporary directory
temp_dir=$(mktemp -d)

log "Getting Custom Resources in OpenShift project ${CP4D_PROJECT}..."
oc get --no-headers -n $CP4D_PROJECT $(oc api-resources --namespaced=true --verbs=list -o name | grep ibm | awk '{printf "%s%s",sep,$0;sep=","}')  --ignore-not-found -o=custom-columns=KIND:.kind,NAME:.metadata.name --sort-by='kind' > ${temp_dir}/cp4d-resources.out

# 
# First the script deletes all CP4D custom resources in the specified project
# Some of these may take too long or they may fail to delete, hence --wait=false it specified so that the command doesn't wait
# Then the finalizer is removed using oc patch, which will delete the custom resource and all OpenShift resources it owns
#
resource_deleted=false
log "Delete all Custom Resources except the base ones"
while read -r line;do
    read -r CR CR_NAME <<< "${line}"
    case $CR in
        ZenService|Ibmcpd|CommonService|OperandRequest|ResourcePlan)
        ;;
        *)
        log "Deleting $CR $CR_NAME"
        oc delete -n ${CP4D_PROJECT} ${CR} ${CR_NAME} --wait=false --ignore-not-found
        oc patch -n ${CP4D_PROJECT} ${CR}/${CR_NAME} --type=merge -p '{"metadata": {"finalizers":null}}' 2> /dev/null
        resource_deleted=true
        ;;
    esac
done < ${temp_dir}/cp4d-resources.out

# 
# Wait a bit to give OpenShift a chance to terminate the resources. You can check the pods in the CP4D project to see if
# they are terminating.
#
if ${resource_deleted};then
    log "Waiting a jiffy for pods to start terminating"
    sleep 10
fi

#
# Delete the remaining CP4D custom resources - Ibmcpd, CommonService and OperandRequest
#
resource_deleted=false
log "Delete remaining Custom Resources"
while read -r line;do
    read -r CR CR_NAME <<< "${line}"
    case $CR in
        Ibmcpd|CommonService|OperandRequest|ResourcePlan)
        log "Deleting $CR $CR_NAME"
        oc delete -n ${CP4D_PROJECT} ${CR} ${CR_NAME} --wait=false --ignore-not-found
        oc patch -n ${CP4D_PROJECT} ${CR}/${CR_NAME} --type=merge -p '{"metadata": {"finalizers":null}}' 2> /dev/null
        resource_deleted=true
        ;;
        *)
        ;;
    esac
done < ${temp_dir}/cp4d-resources.out

if ${resource_deleted};then
    log "Waiting a jiffy for remaining pods to start terminating"
    sleep 10
fi

log "Delete role binding if Cloud Pak for Data was connected to IAM"
oc delete rolebinding -n ${CP4D_PROJECT} admin --ignore-not-found --wait=false
oc patch -n ${CP4D_PROJECT} rolebinding/admin --type=merge -p '{"metadata": {"finalizers":null}}' 2> /dev/null

#
# Now the CP4D project should be empty and can be deleted, this may take a while (5-15 minutes)
#
log "Deleting ${CP4D_PROJECT} namespace"
oc delete ns ${CP4D_PROJECT}


#
# Delete all CRs in the ibm-common-services project
# Here we do wait for deletion to complete as it typically does finish ok in a few minutes
#
log "Deleting everything in the ibm-common-services project"
oc project ibm-common-services
oc delete CommonService  -n ibm-common-services common-service --ignore-not-found
oc delete Scheduling -n ibm-common-services --all --ignore-not-found
oc delete sub -n ibm-common-services -l operators.coreos.com/ibm-common-service-operator.ibm-common-services --ignore-not-found
oc delete csv -n ibm-common-services -l operators.coreos.com/ibm-common-service-operator.ibm-common-services --ignore-not-found

oc delete operandrequest -n ibm-common-services --all --ignore-not-found

oc delete operandconfig -n ibm-common-services --all --ignore-not-found

oc delete operandregistry -n ibm-common-services --all --ignore-not-found

oc delete nss -n ibm-common-services --all --ignore-not-found

oc delete sub -n ibm-common-services --all --ignore-not-found
oc delete csv -n ibm-common-services --all --ignore-not-found

log "Delete role binding in Foundation Services if Cloud Pak for Data was connected to IAM"
oc delete rolebinding -n ibm-common-services admin --ignore-not-found --wait=false
oc patch -n ibm-common-services rolebinding/admin --type=merge -p '{"metadata": {"finalizers":null}}' 2> /dev/null

#
# Now the ibm-common-services project should be empty and can be deleted
#
log "Deleting ibm-common-services project"
oc delete ns ibm-common-services

#
# Delete all catalog sources belonging to CP4D
#
log "Deleting IBM catalog sources"
oc delete catsrc -n openshift-marketplace \
    $(oc get catsrc -n openshift-marketplace \
    --no-headers | grep -E 'IBM|MANTA' | awk '{print $1}') --ignore-not-found

#
# Delete IBM CRDs that don't have an instance
#
log "Deleting IBM CRDs that don't have an instance anymore"
for crd in $(oc get crd --no-headers | awk '{print $1}' | grep -E '\.ibm|mantaflows\.adl');do
    if [[ "$(oc get ${crd} --no-headers -A 2>/dev/null)" == "" ]] && [[ "${crd}" != *ocscluster* ]];then
        oc delete crd $crd
    fi
done

exit 0