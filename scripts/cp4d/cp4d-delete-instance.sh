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

oc get project ${CP4D_PROJECT} > /dev/null 2>&1
if [ $? -eq 0 ];then

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
    oc delete authentication.operator.ibm.com -n ${CP4D_PROJECT} example-authentication --ignore-not-found --wait=false
    oc patch -n ${CP4D_PROJECT} authentication.operator.ibm.com/example-authentication --type=merge -p '{"metadata": {"finalizers":null}}' 2> /dev/null

    #
    # Now the CP4D project should be empty and can be deleted, this may take a while (5-15 minutes)
    #
    log "Deleting ${CP4D_PROJECT} namespace"
    oc delete ns ${CP4D_PROJECT}
else
    echo "Project ${CP4D_PROJECT} does not exist, skipping"
fi

CP4D_OPERATORS=${CP4D_PROJECT}-operators
oc get project ${CP4D_OPERATORS} > /dev/null 2>&1
if [ $? -eq 0 ];then
    log "Deleting everything in the ${CP4D_OPERATORS} project"
    oc delete CommonService  -n ${CP4D_OPERATORS} common-service --ignore-not-found
    oc delete sub -n ${CP4D_OPERATORS} -l operators.coreos.com/ibm-common-service-operator.ibm-common-services --ignore-not-found
    oc delete csv -n ${CP4D_OPERATORS} -l operators.coreos.com/ibm-common-service-operator.ibm-common-services --ignore-not-found

    for opreq in $(oc get operandrequest -n ${CP4D_OPERATORS} --no-headers | awk '{print $1}');do
        oc delete operandrequest -n ${CP4D_OPERATORS} --all --ignore-not-found --wait=false
        oc patch -n ${CP4D_OPERATORS} operandrequest/${opreq} --type=merge -p '{"metadata": {"finalizers":null}}' 2> /dev/null
    done
    oc delete operandconfig -n ${CP4D_OPERATORS} --all --ignore-not-found
    oc delete operandregistry -n ${CP4D_OPERATORS} --all --ignore-not-found
    oc delete nss -n ${CP4D_OPERATORS} --all --ignore-not-found

    oc delete sub -n ${CP4D_OPERATORS} --all --ignore-not-found
    oc delete csv -n ${CP4D_OPERATORS} --all --ignore-not-found

    log "Deleting ${CP4D_OPERATORS} project"
    oc delete ns ${CP4D_OPERATORS}
else
    echo "Project ${CP4D_OPERATORS} does not exist, skipping"
fi

CP4D_OPERATORS=${CP4D_PROJECT}-operators
oc get project ${CP4D_OPERATORS} > /dev/null 2>&1
if [ $? -eq 0 ];then
    log "Deleting everything in the ${CP4D_OPERATORS} project"
    oc delete CommonService  -n ${CP4D_OPERATORS} common-service --ignore-not-found
    oc delete sub -n ${CP4D_OPERATORS} -l operators.coreos.com/ibm-common-service-operator.ibm-common-services --ignore-not-found
    oc delete csv -n ${CP4D_OPERATORS} -l operators.coreos.com/ibm-common-service-operator.ibm-common-services --ignore-not-found

    for opreq in $(oc get operandrequest -n ${CP4D_OPERATORS} --no-headers | awk '{print $1}');do
        oc delete operandrequest -n ${CP4D_OPERATORS} --all --ignore-not-found --wait=false
        oc patch -n ${CP4D_OPERATORS} operandrequest/${opreq} --type=merge -p '{"metadata": {"finalizers":null}}' 2> /dev/null
    done
    oc delete operandconfig -n ${CP4D_OPERATORS} --all --ignore-not-found
    oc delete operandregistry -n ${CP4D_OPERATORS} --all --ignore-not-found
    oc delete nss -n ${CP4D_OPERATORS} --all --ignore-not-found

    oc delete sub -n ${CP4D_OPERATORS} --all --ignore-not-found
    oc delete csv -n ${CP4D_OPERATORS} --all --ignore-not-found

    log "Deleting ${CP4D_OPERATORS} project"
    oc delete ns ${CP4D_OPERATORS}
else
    echo "Project ${CP4D_OPERATORS} does not exist, skipping"
fi

IBM_SCHEDULING=ibm-scheduling
oc get project ${IBM_SCHEDULING} > /dev/null 2>&1
if [ $? -eq 0 ];then
    log "Deleting everything in the ${IBM_SCHEDULING} project"
    oc delete Scheduling  -n ${IBM_SCHEDULING} --all --ignore-not-found
    oc delete sub -n ${IBM_SCHEDULING} --all --ignore-not-found
    oc delete csv -n ${IBM_SCHEDULING} --all --ignore-not-found

    log "Deleting ${IBM_SCHEDULING} project"
    oc delete ns ${IBM_SCHEDULING}
else
    echo "Project ${IBM_SCHEDULING} does not exist, skipping"
fi

IBM_LICENSING=ibm-licensing
oc get project ${IBM_LICENSING} > /dev/null 2>&1
if [ $? -eq 0 ];then
    log "Deleting everything in the ${IBM_LICENSING} project"
    oc delete ibmlicensing  --all --ignore-not-found
    oc delete sub -n ${IBM_LICENSING} --all --ignore-not-found
    oc delete csv -n ${IBM_LICENSING} --all --ignore-not-found

    log "Deleting ${IBM_LICENSING} project"
    oc delete ns ${IBM_LICENSING}
else
    echo "Project ${IBM_LICENSING} does not exist, skipping"
fi

IBM_CERT_MANAGER=ibm-cert-manager
oc get project ${IBM_CERT_MANAGER} > /dev/null 2>&1
if [ $? -eq 0 ];then
    log "Deleting everything in the ${IBM_CERT_MANAGER} project"
    oc delete lease -n ${IBM_CERT_MANAGER} --all --ignore-not-found
    oc delete endpointslice -n ${IBM_CERT_MANAGER}  --all --ignore-not-found
    oc delete endpoints -n ${IBM_CERT_MANAGER}  --all --ignore-not-found
    
    oc delete sub -n ${IBM_CERT_MANAGER} --all --ignore-not-found
    oc delete csv -n ${IBM_CERT_MANAGER} --all --ignore-not-found

    log "Deleting ${IBM_CERT_MANAGER} project"
    oc delete ns ${IBM_CERT_MANAGER}
else
    echo "Project ${IBM_CERT_MANAGER} does not exist, skipping"
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
    oc delete ns ${IBM_CS_CONTROL}
else
    echo "Project ${IBM_CS_CONTROL} does not exist, skipping"
fi

echo "Deleting common-service maps"
oc delete cm -n kube-public common-service-maps --ignore-not-found

#
# Delete all CRs in the ibm-common-services project
# Here we do wait for deletion to complete as it typically does finish ok in a few minutes
#
oc get project ibm-common-services > /dev/null 2>&1
if [ $? -eq 0 ];then
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
fi

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