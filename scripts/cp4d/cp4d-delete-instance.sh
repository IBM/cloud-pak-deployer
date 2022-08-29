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

# Create temporary directory
temp_dir=$(mktemp -d)

log "Getting Custom Resources in OpenShift project ${CP4D_PROJECT}..."
oc get --no-headers -n $CP4D_PROJECT $(oc api-resources --namespaced=true --verbs=list -o name | grep ibm | awk '{printf "%s%s",sep,$0;sep=","}')  --ignore-not-found -o=custom-columns=KIND:.kind,NAME:.metadata.name --sort-by='kind' > ${temp_dir}/cp4d-resources.out

resource_deleted=false
log "Delete all Custom Resources except the base ones"
while read -r line;do
    read -r CR CR_NAME <<< "${line}"
    case $CR in
        ZenService|Ibmcpd|CommonService|OperandRequest)
        ;;
        *)
        log "Deleting $CR $CR_NAME"
        oc delete -n ${CP4D_PROJECT} ${CR} ${CR_NAME} --wait=false
        oc patch -n ${CP4D_PROJECT} ${CR}/${CR_NAME} --type=merge -p '{"metadata": {"finalizers":null}}'
        resource_deleted=true
        ;;
    esac
done < ${temp_dir}/cp4d-resources.out

if ${resource_deleted};then
    log "Waiting a bit for pods to start terminating"
    sleep 10
fi

resource_deleted=false
log "Delete remaining Custom Resources"
while read -r line;do
    read -r CR CR_NAME <<< "${line}"
    case $CR in
        Ibmcpd|CommonService|OperandRequest)
        log "Deleting $CR $CR_NAME"
        oc delete -n ${CP4D_PROJECT} ${CR} ${CR_NAME} --wait=false
        oc patch -n ${CP4D_PROJECT} ${CR}/${CR_NAME} --type=merge -p '{"metadata": {"finalizers":null}}'
        resource_deleted=true
        ;;
        *)
        ;;
    esac
done < ${temp_dir}/cp4d-resources.out

if ${resource_deleted};then
    log "Waiting a bit for remaining pods to start terminating"
    sleep 10
fi

log "Deleting ${CP4D_PROJECT} namespace"
oc delete ns ${CP4D_PROJECT}

log "Deleting everything in the ibm-common-services project"
oc project ibm-common-services
oc delete CommonService  -n ibm-common-services common-service
oc delete sub -n ibm-common-services -l operators.coreos.com/ibm-common-service-operator.ibm-common-services
oc delete csv -n ibm-common-services -l operators.coreos.com/ibm-common-service-operator.ibm-common-services

oc delete operandrequest -n ibm-common-services --all

oc delete operandconfig -n ibm-common-services --all

oc delete operandregistry -n ibm-common-services --all

oc delete nss -n ibm-common-services --all

oc delete sub -n ibm-common-services --all
oc delete csv -n ibm-common-services --all

log "Deleting ibm-common-services project"
oc delete ns ibm-common-services

log "Deleting IBM catalog sources"
oc delete catsrc -n openshift-marketplace \
    $(oc get catsrc -n openshift-marketplace \
    --no-headers | grep -i ibm | awk '{print $1}')

exit 0