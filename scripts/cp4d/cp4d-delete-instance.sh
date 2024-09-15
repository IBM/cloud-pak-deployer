#!/bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

get_logtime() {
  echo $(date "+%Y-%m-%d %H:%M:%S")
}

log() {
  LOG_TIME=$(get_logtime)
  printf "[${LOG_TIME}] ${1}\n"
}

wait_ns_deleted() {
    NS=$1
    log "Waiting for deletion of namespace ${NS} ..."
    while $(oc get ns ${NS} > /dev/null 2>&1);do
        sleep 1
    done
}

delete_operator_ns() {
    CP4D_OPERATORS=$1
    oc get project ${CP4D_OPERATORS} > /dev/null 2>&1
    if [ $? -eq 0 ];then
        log "Deleting everything in the ${CP4D_OPERATORS} project"
        oc delete CommonService  -n ${CP4D_OPERATORS} common-service --ignore-not-found
        oc delete sub -n ${CP4D_OPERATORS} -l operators.coreos.com/ibm-common-service-operator.${CP4D_OPERATORS} --ignore-not-found
        oc delete csv -n ${CP4D_OPERATORS} -l operators.coreos.com/ibm-common-service-operator.${CP4D_OPERATORS} --ignore-not-found

        oc delete operandconfig -n ${CP4D_OPERATORS} --all --ignore-not-found
        oc delete operandregistry -n ${CP4D_OPERATORS} --all --ignore-not-found
        oc delete nss -n ${CP4D_OPERATORS} --all --ignore-not-found

        oc delete sub -n ${CP4D_OPERATORS} --all --ignore-not-found
        oc delete csv -n ${CP4D_OPERATORS} --all --ignore-not-found

        log "Deleting ${CP4D_OPERATORS} project"
        oc delete ns ${CP4D_OPERATORS} --ignore-not-found --wait=false
        while [ $(oc get operandrequest -n ${CP4D_OPERATORS} --no-headers 2>/dev/null | wc -l) -ne 0  ];do
            for opreq in $(oc get operandrequest -n ${CP4D_OPERATORS} --no-headers | awk '{print $1}');do
                oc delete operandrequest -n ${CP4D_OPERATORS} ${opreq} --ignore-not-found --wait=false
                oc patch -n ${CP4D_OPERATORS} operandrequest/${opreq} --type=merge -p '{"metadata": {"finalizers":null}}' 2> /dev/null
            done
        done
        wait_ns_deleted ${CP4D_OPERATORS}
    else
        echo "Project ${CP4D_OPERATORS} does not exist, skipping"
    fi
}

#When running cp4d-delete-instance.sh, the script always deletes the Certificate Manager and the License Manager.
#This should not be done if these shared services are still in use, for example in another CP4D instance.
check_shared_resources() {
    SHARED_RESOURCE_TYPE=$1
    SHARED_RESOURCE_NAMESPACE=$2
    STATE_VAR=$3

    if [ "$(oc get ${SHARED_RESOURCE_TYPE} --all-namespaces --no-headers 2>/dev/null)" != "" ]; then
        echo "Found instances of ${SHARED_RESOURCE_TYPE}, keeping ${SHARED_RESOURCE_NAMESPACE} namespace"
        eval "${STATE_VAR}=0"
    else
        echo "No instances of ${SHARED_RESOURCE_TYPE} found"
        eval "${STATE_VAR}=1"
    fi
}

CP4D_PROJECT=$1
if [ -z "${CP4D_PROJECT}" ];then
    echo "Usage: $0 <cp4d-project>"
    exit 1
fi

# Ask for final confirmation to delete the CP4D instance
if [ -z "${CPD_CONFIRM_DELETE}" ];then
    read -p "Are you sure you want to delete CP4D instance ${CP4D_PROJECT}, operators project ${CP4D_PROJECT}-operators and Foundational Services (y/N)? " -r
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

oc get project ${CP4D_PROJECT} > /dev/null 2>&1
if [ $? -eq 0 ];then

    # Delete instance namespace at the beginning to avoid additional CRs being created
    oc delete ns ${CP4D_PROJECT} --ignore-not-found --wait=false

    log "Getting Custom Resources in OpenShift project ${CP4D_PROJECT}..."
    oc get --no-headers -n $CP4D_PROJECT $(oc api-resources --namespaced=true --verbs=list -o name | grep -E 'ibm|caikitruntimestacks' | awk '{printf "%s%s",sep,$0;sep=","}')  --ignore-not-found -o=custom-columns=KIND:.kind,NAME:.metadata.name --sort-by='kind' > ${temp_dir}/cp4d-resources.out

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

    log "Delete role binding if Cloud Pak for Data was connected to IAM"
    oc delete rolebinding -n ${CP4D_PROJECT} admin --ignore-not-found --wait=false
    oc patch -n ${CP4D_PROJECT} rolebinding/admin --type=merge -p '{"metadata": {"finalizers":null}}' 2> /dev/null
    oc delete authentication.operator.ibm.com -n ${CP4D_PROJECT} example-authentication --ignore-not-found --wait=false
    oc patch -n ${CP4D_PROJECT} authentication.operator.ibm.com/example-authentication --type=merge -p '{"metadata": {"finalizers":null}}' 2> /dev/null

    #
    # Now the CP4D project should be empty and can be deleted, this may take a while (5-15 minutes)
    #
    wait_ns_deleted ${CP4D_PROJECT}
else
    echo "Project ${CP4D_PROJECT} does not exist, skipping"
fi

# Delete operators in Cloud Pak for Data 4.7+ operators namespace
delete_operator_ns ${CP4D_PROJECT}-operators
# Delete operators in ibm-common-services
delete_operator_ns ibm-common-services

# Delete operators in new operators namespace
delete_operator_ns ${CP4D_PROJECT}-operators

# Delete operators in ibm-knative-events
delete_operator_ns ibm-knative-events

KNATIVE_EVENTING=knative-eventing
oc get project ${KNATIVE_EVENTING} > /dev/null 2>&1
if [ $? -eq 0 ];then
    log "Deleting everything in the ${KNATIVE_EVENTING} project"

    log "Getting Custom Resources in OpenShift project ${KNATIVE_EVENTING}..."
    oc get --no-headers -n $KNATIVE_EVENTING $(oc api-resources --namespaced=true --verbs=list -o name | grep ibm | awk '{printf "%s%s",sep,$0;sep=","}')  --ignore-not-found -o=custom-columns=KIND:.kind,NAME:.metadata.name --sort-by='kind' > ${temp_dir}/knative-eventing-resources.out

    log "Delete all Custom Resources"
    while read -r line;do
        read -r CR CR_NAME <<< "${line}"
        log "Deleting $CR $CR_NAME"
        oc delete -n ${KNATIVE_EVENTING} ${CR} ${CR_NAME} --wait=false --ignore-not-found
        oc patch -n ${KNATIVE_EVENTING} ${CR}/${CR_NAME} --type=merge -p '{"metadata": {"finalizers":null}}' 2> /dev/null
    done < ${temp_dir}/knative-eventing-resources.out

    log "Deleting ${KNATIVE_EVENTING} project"
    oc delete ns ${KNATIVE_EVENTING} --ignore-not-found --wait=false
    wait_ns_deleted ${KNATIVE_EVENTING}
else
    echo "Project ${KNATIVE_EVENTING} does not exist, skipping"
fi

KNATIVE_SERVING=knative-serving
oc get project ${KNATIVE_SERVING} > /dev/null 2>&1
if [ $? -eq 0 ];then
    log "Deleting everything in the ${KNATIVE_SERVING} project"

    log "Deleting ${KNATIVE_SERVING} project"
    oc delete ns ${KNATIVE_SERVING} --ignore-not-found --wait=false
    wait_ns_deleted ${KNATIVE_SERVING}
else
    echo "Project ${KNATIVE_SERVING} does not exist, skipping"
fi

APP_CONNECT=ibm-app-connect
oc get project ${APP_CONNECT} > /dev/null 2>&1
if [ $? -eq 0 ];then
    log "Deleting everything in the ${APP_CONNECT} project"

    log "Deleting ${APP_CONNECT} project"
    oc delete ns ${APP_CONNECT} --ignore-not-found --wait=false
    wait_ns_deleted ${APP_CONNECT}
else
    echo "Project ${APP_CONNECT} does not exist, skipping"
fi

IBM_SCHEDULING=ibm-scheduling
oc get project ${IBM_SCHEDULING} > /dev/null 2>&1
if [ $? -eq 0 ];then
    log "Deleting everything in the ${IBM_SCHEDULING} project"
    oc delete Scheduling  -n ${IBM_SCHEDULING} --all --ignore-not-found
    oc delete sub -n ${IBM_SCHEDULING} --all --ignore-not-found
    oc delete csv -n ${IBM_SCHEDULING} --all --ignore-not-found

    log "Deleting ${IBM_SCHEDULING} project"
    oc delete ns ${IBM_SCHEDULING} --ignore-not-found --wait=false
    wait_ns_deleted ${IBM_SCHEDULING}
    oc delete ns ${IBM_SCHEDULING} --ignore-not-found --wait=false
    wait_ns_deleted ${IBM_SCHEDULING}
else
    echo "Project ${IBM_SCHEDULING} does not exist, skipping"
fi

check_shared_resources ibmlicensingdefinition.operator.ibm.com ibm-licensing DELETE_LICENSING
if [ "${DELETE_LICENSING}" -eq 1 ]; then
    IBM_LICENSING=ibm-licensing
    oc get project ${IBM_LICENSING} > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        log "Deleting everything in the ${IBM_LICENSING} project"
        oc delete ibmlicensing  --all --ignore-not-found
        oc delete sub -n ${IBM_LICENSING} --all --ignore-not-found
        oc delete csv -n ${IBM_LICENSING} --all --ignore-not-found

        log "Deleting ${IBM_LICENSING} project"
        oc delete ns ${IBM_LICENSING} --ignore-not-found --wait=false
        wait_ns_deleted ${IBM_LICENSING}
        oc delete ns ${IBM_LICENSING} --ignore-not-found --wait=false
        wait_ns_deleted ${IBM_LICENSING}
    else
        echo "Project ${IBM_LICENSING} does not exist, skipping"
    fi
else
    echo "Keeping ${IBM_LICENSING} namespace due to shared resources"
fi

check_shared_resources certificaterequests.cert-manager.io ibm-cert-manager DELETE_CERT_MANAGER
if [ "${DELETE_CERT_MANAGER}" -eq 1 ]; then
    IBM_CERT_MANAGER=ibm-cert-manager
    oc get project ${IBM_CERT_MANAGER} > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        log "Deleting everything in the ${IBM_CERT_MANAGER} project"
        oc delete lease -n ${IBM_CERT_MANAGER} --all --ignore-not-found
        oc delete endpointslice -n ${IBM_CERT_MANAGER}  --all --ignore-not-found
        oc delete endpoints -n ${IBM_CERT_MANAGER}  --all --ignore-not-found

        oc delete sub -n ${IBM_CERT_MANAGER} --all --ignore-not-found
        oc delete csv -n ${IBM_CERT_MANAGER} --all --ignore-not-found

        log "Deleting ${IBM_CERT_MANAGER} project"
        oc delete ns ${IBM_CERT_MANAGER} --ignore-not-found --wait=false
        wait_ns_deleted ${IBM_CERT_MANAGER}
        oc delete ns ${IBM_CERT_MANAGER} --ignore-not-found --wait=false
        wait_ns_deleted ${IBM_CERT_MANAGER}
    else
        echo "Project ${IBM_CERT_MANAGER} does not exist, skipping"
    fi
else
    echo "Keeping ${IBM_CERT_MANAGER} namespace due to shared resources"
fi

# Delete other elements belonging to CP4D install
echo "Deleting MutatingWebhookConfigurations"
oc delete MutatingWebhookConfiguration ibm-common-service-webhook-configuration --ignore-not-found
oc delete MutatingWebhookConfiguration ibm-operandrequest-webhook-configuration --ignore-not-found
oc delete MutatingWebhookConfiguration ibm-operandrequest-webhook-configuration-cpd-operators --ignore-not-found

echo "Deleting ValidatingWebhookConfiguration"
oc delete ValidatingWebhookConfiguration ibm-common-service-validating-webhook-cpd-operators --ignore-not-found
oc delete ValidatingWebhookConfiguration ibm-cs-ns-mapping-webhook-configuration --ignore-not-found

IBM_CS_CONTROL=cs-control
oc get project ${IBM_CS_CONTROL} > /dev/null 2>&1
if [ $? -eq 0 ];then
    log "Deleting everything in the ${IBM_CS_CONTROL} project"
    oc delete nss -n ${IBM_CS_CONTROL} --all --ignore-not-found

    log "Deleting ${IBM_CS_CONTROL} project"
    oc delete ns ${IBM_CS_CONTROL} --ignore-not-found --wait=false
    wait_ns_deleted ${IBM_CS_CONTROL}
    oc delete ns ${IBM_CS_CONTROL} --ignore-not-found --wait=false
    wait_ns_deleted ${IBM_CS_CONTROL}
else
    echo "Project ${IBM_CS_CONTROL} does not exist, skipping"
fi

echo "Deleting common-service maps"
oc delete cm -n kube-public common-service-maps --ignore-not-found

#
# Delete all catalog sources belonging to CP4D
#
log "Deleting IBM catalog sources"
oc delete catsrc -n openshift-marketplace \
    $(oc get catsrc -n openshift-marketplace \
    --no-headers | grep -E 'IBM|MANTA' | awk '{print $1}') --ignore-not-found 2>/dev/null

#
# Delete IBM CRDs that don't have an instance
#
log "Deleting IBM CRDs that don't have an instance anymore"
for crd in $(oc get crd --no-headers | awk '{print $1}' | grep -E '\.ibm|mantaflows\.adl');do
    if [[ "$(oc get ${crd} --no-headers -A 2>/dev/null)" != "" ]] ;then
        log "Not deleting CRD ${crd}, still has some instances"
    elif [[ "${crd}" == *ocscluster* ]];then
        log "Not deleting OpenShift Data Foundation CRD ${crd}, still needed"
    elif [[ "${crd}" == *ibmlicensing* ]] && [ "${DELETE_LICENSING}" -ne 1 ];then
        log "Not deleting license server CRD ${crd}, still needed"
    elif [[ "${crd}" == *cert* ]] && [ "${DELETE_CERT_MANAGER}" -ne 1 ];then
        log "Not deleting certificate manager CRD ${crd}, still needed"
    else
        oc delete crd $crd
    fi
done


exit 0