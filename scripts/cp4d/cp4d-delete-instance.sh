#!/bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

command_usage() {
  echo
  echo "Usage:"
  echo "$(basename $0) <INSTANCE NAMESPACE>"
  echo "$(basename $0) -n <INSTANCE NAMESPACE> [--operator-ns <OPERATOR NAMESPACE>] [--force-finalizer] [--timeout <SECONDS>]"
  echo
  echo "Options:"
  echo "  --force-finalizer    Force removal of finalizers using OpenShift REST API for stuck namespaces"
  echo "  --timeout <SECONDS>  Timeout in seconds for namespace deletion (default: 900)"
  echo
  exit $1
}

#
# PARSE
#
if [ "$#" -lt 1 ]; then
    echo "Error: Missing namespace argument."
    command_usage 2
elif [ "$#" -eq 1 ];then
    export INSTANCE_NS=$1
    export OPERATOR_NS="${INSTANCE_NS}-operators"
else
    PARAMS=""
    while (( "$#" )); do
    case "$1" in
    --help|-h)
        command_usage 0
        ;;
    --instance-namespace*|-n*)
        if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
        export INSTANCE_NS="${1#*=}"
        shift 1
        else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
        export INSTANCE_NS=$2
        shift 2
        else
        echo "Error: Missing instance namespace argument."
        command_usage 2
        fi
        fi
        shift 1
        ;;
    --operator-ns*)
        if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
        export OPERATOR_NS="${1#*=}"
        shift 1
        else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
        export OPERATOR_NS=$2
        shift 2
        else
        echo "Error: Missing operator namespace argument."
        command_usage 2
        fi
        fi
        shift 1
        ;;
    --force-finalizer)
        export FORCE_FINALIZER=true
        shift 1
        ;;
    --timeout*)
        if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
        export NAMESPACE_DELETE_TIMEOUT="${1#*=}"
        shift 1
        else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
        export NAMESPACE_DELETE_TIMEOUT=$2
        shift 2
        else
        echo "Error: Missing timeout value."
        command_usage 2
        fi
        fi
        shift 1
        ;;
    *) # preserve remaining arguments
        PARAMS="$PARAMS $1"
        shift
        ;;
    esac
    done
fi

get_logtime() {
  echo $(date "+%Y-%m-%d %H:%M:%S")
}

log() {
  LOG_TIME=$(get_logtime)
  printf "[${LOG_TIME}] ${1}\n"
}

wait_ns_deleted() {
    NS=$1
    TIMEOUT=${NAMESPACE_DELETE_TIMEOUT:-900}
    ELAPSED=0
    RETRY_COUNT=0
    MAX_RETRIES=3
    log "Waiting for deletion of namespace ${NS} (timeout: ${TIMEOUT}s)..."
    
    while $(oc get ns ${NS} > /dev/null 2>&1);do
        sleep 5
        ELAPSED=$((ELAPSED + 5))
        
        if [ $ELAPSED -ge $TIMEOUT ]; then
            log "WARNING: Timeout reached waiting for namespace ${NS} deletion after ${TIMEOUT}s"
            log "Namespace ${NS} may still be in Terminating state"
            
            # Run diagnostics
            diagnose_namespace_stuck ${NS}
            
            if [ "${FORCE_FINALIZER}" = "true" ] && [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
                RETRY_COUNT=$((RETRY_COUNT + 1))
                log "Attempting forced cleanup (attempt ${RETRY_COUNT}/${MAX_RETRIES})..."
                force_remove_finalizers ${NS}
                
                # Reset timeout for retry
                ELAPSED=0
                TIMEOUT=300  # Shorter timeout for retries
                log "Waiting additional ${TIMEOUT}s after forced cleanup..."
                continue
            else
                log "ERROR: Failed to delete namespace ${NS} after ${MAX_RETRIES} retry attempts"
                return 1
            fi
        fi
        
        # Log progress every 60 seconds
        if [ $((ELAPSED % 60)) -eq 0 ] && [ $ELAPSED -gt 0 ]; then
            log "Still waiting for ${NS} deletion... (${ELAPSED}s elapsed)"
        fi
    done
    log "Project ${NS} deleted successfully"
    return 0
}

force_remove_finalizers() {
    NS=$1
    if [ "${FORCE_FINALIZER}" = "true" ]; then
        log "Force removing finalizers for ${NS} namespace"
        
        # First, try to remove finalizers from blocking resources
        force_remove_resource_finalizers ${NS}
        
        # Then remove namespace finalizers
        if oc get ns ${NS} -o json > ${temp_dir}/${NS}-finalizer.json 2>/dev/null; then
            sed -i '/"kubernetes"/d' ${temp_dir}/${NS}-finalizer.json
            OC_SERVER_URL="${OC_SERVER_URL:-$(oc whoami --show-server)}"
            OC_TOKEN="${OC_TOKEN:-$(oc whoami -t)}"
            curl --silent --insecure -H "Content-Type: application/json" \
                -H "Authorization: Bearer ${OC_TOKEN}" \
                -X PUT --data-binary @"${temp_dir}/${NS}-finalizer.json" \
                "${OC_SERVER_URL}/api/v1/namespaces/${NS}/finalize" > /dev/null 2>&1
            rm -f "${temp_dir}/${NS}-finalizer.json"
            log "Namespace finalizers removed for ${NS}"
        fi
    fi
}

force_remove_resource_finalizers() {
    NS=$1
    log "Checking for resources with finalizers in namespace ${NS}..."
    
    # Remove finalizers from PVCs (often block namespace deletion)
    if oc get pvc -n ${NS} --no-headers 2>/dev/null | grep -q .; then
        log "Removing finalizers from PVCs in ${NS}..."
        for pvc in $(oc get pvc -n ${NS} --no-headers 2>/dev/null | awk '{print $1}'); do
            oc patch pvc/${pvc} -n ${NS} --type=merge -p '{"metadata": {"finalizers":null}}' 2>/dev/null
        done
    fi
    
    # Remove finalizers from PVs associated with the namespace
    if oc get pv --no-headers 2>/dev/null | grep ${NS} | grep -q .; then
        log "Removing finalizers from PVs associated with ${NS}..."
        for pv in $(oc get pv --no-headers 2>/dev/null | grep ${NS} | awk '{print $1}'); do
            oc patch pv/${pv} --type=merge -p '{"metadata": {"finalizers":null}}' 2>/dev/null
        done
    fi
    
    # Remove finalizers from Pods stuck in Terminating
    if oc get pods -n ${NS} --field-selector=status.phase=Terminating --no-headers 2>/dev/null | grep -q .; then
        log "Force deleting Terminating pods in ${NS}..."
        for pod in $(oc get pods -n ${NS} --field-selector=status.phase=Terminating --no-headers 2>/dev/null | awk '{print $1}'); do
            oc delete pod/${pod} -n ${NS} --grace-period=0 --force 2>/dev/null
        done
    fi
    
    # Remove finalizers from Services
    if oc get svc -n ${NS} --no-headers 2>/dev/null | grep -q .; then
        log "Removing finalizers from Services in ${NS}..."
        for svc in $(oc get svc -n ${NS} --no-headers 2>/dev/null | awk '{print $1}'); do
            oc patch svc/${svc} -n ${NS} --type=merge -p '{"metadata": {"finalizers":null}}' 2>/dev/null
        done
    fi
    
    # Remove finalizers from ConfigMaps with finalizers
    if oc get cm -n ${NS} --no-headers 2>/dev/null | grep -q .; then
        for cm in $(oc get cm -n ${NS} -o json 2>/dev/null | jq -r '.items[] | select(.metadata.finalizers != null) | .metadata.name'); do
            if [ ! -z "$cm" ]; then
                log "Removing finalizers from ConfigMap ${cm} in ${NS}..."
                oc patch cm/${cm} -n ${NS} --type=merge -p '{"metadata": {"finalizers":null}}' 2>/dev/null
            fi
        done
    fi
    
    # Remove finalizers from Secrets with finalizers
    if oc get secret -n ${NS} --no-headers 2>/dev/null | grep -q .; then
        for secret in $(oc get secret -n ${NS} -o json 2>/dev/null | jq -r '.items[] | select(.metadata.finalizers != null) | .metadata.name'); do
            if [ ! -z "$secret" ]; then
                log "Removing finalizers from Secret ${secret} in ${NS}..."
                oc patch secret/${secret} -n ${NS} --type=merge -p '{"metadata": {"finalizers":null}}' 2>/dev/null
            fi
        done
    fi
}

diagnose_namespace_stuck() {
    NS=$1
    log "=== Diagnostic information for stuck namespace ${NS} ==="
    
    # Check for resources still in the namespace
    log "Resources still present in namespace:"
    oc api-resources --verbs=list --namespaced -o name 2>/dev/null | \
        xargs -I {} sh -c "oc get {} -n ${NS} --ignore-not-found --no-headers 2>/dev/null | head -5" | \
        grep -v "^$" || log "No resources found"
    
    # Check namespace status
    log "Namespace status:"
    oc get ns ${NS} -o json 2>/dev/null | jq -r '.status' || log "Cannot get namespace status"
    
    # Check for finalizers on namespace
    log "Namespace finalizers:"
    oc get ns ${NS} -o json 2>/dev/null | jq -r '.metadata.finalizers[]' || log "No finalizers found"
    
    # Check for stuck pods
    log "Pods in Terminating state:"
    oc get pods -n ${NS} --field-selector=status.phase=Terminating 2>/dev/null || log "No terminating pods"
    
    # Check for PVCs
    log "PersistentVolumeClaims:"
    oc get pvc -n ${NS} 2>/dev/null || log "No PVCs found"
    
    log "=== End diagnostic information ==="
}

delete_operator_ns() {
    CP4D_OPERATORS=$1
    oc get project ${CP4D_OPERATORS} > /dev/null 2>&1
    if [ $? -eq 0 ];then
        log "Deleting everything in the ${CP4D_OPERATORS} project"
        oc delete CommonService  -n ${CP4D_OPERATORS} common-service --ignore-not-found
        oc delete subscriptions.operators.coreos.com -n ${CP4D_OPERATORS} -l operators.coreos.com/ibm-common-service-operator.${CP4D_OPERATORS} --ignore-not-found
        oc delete clusterserviceversions.operators.coreos.com -n ${CP4D_OPERATORS} -l operators.coreos.com/ibm-common-service-operator.${CP4D_OPERATORS} --ignore-not-found

        oc delete operandconfig -n ${CP4D_OPERATORS} --all --ignore-not-found
        oc delete operandregistry -n ${CP4D_OPERATORS} --all --ignore-not-found
        oc delete nss -n ${CP4D_OPERATORS} --all --ignore-not-found

        oc delete subscriptions.operators.coreos.com -n ${CP4D_OPERATORS} --all --ignore-not-found
        oc delete clusterserviceversions.operators.coreos.com -n ${CP4D_OPERATORS} --all --ignore-not-found

        log "Deleting ${CP4D_OPERATORS} project"
        oc delete ns ${CP4D_OPERATORS} --ignore-not-found --wait=false
        while [ $(oc get operandrequest -n ${CP4D_OPERATORS} --no-headers 2>/dev/null | wc -l) -ne 0  ];do
            for opreq in $(oc get operandrequest -n ${CP4D_OPERATORS} --no-headers | awk '{print $1}');do
                oc delete operandrequest -n ${CP4D_OPERATORS} ${opreq} --ignore-not-found --wait=false
                oc patch -n ${CP4D_OPERATORS} operandrequest/${opreq} --type=merge -p '{"metadata": {"finalizers":null}}' 2> /dev/null
            done
        done
        force_remove_finalizers ${CP4D_OPERATORS}
        wait_ns_deleted ${CP4D_OPERATORS}
    else
        echo "Project ${CP4D_OPERATORS} does not exist, skipping"
    fi
}

delete_instance_ns() {
    INSTANCE_NS=$1
    oc get project ${INSTANCE_NS} > /dev/null 2>&1
    if [ $? -eq 0 ];then

        # Delete instance namespace at the beginning to avoid additional CRs being created
        oc delete ns ${INSTANCE_NS} --ignore-not-found --wait=false

        log "Getting Custom Resources in OpenShift project ${INSTANCE_NS}..."
        oc get --no-headers -n $INSTANCE_NS $(oc api-resources --namespaced=true --verbs=list -o name | grep -E 'ibm|caikitruntimestacks' | awk '{printf "%s%s",sep,$0;sep=","}')  --ignore-not-found -o=custom-columns=KIND:.kind,NAME:.metadata.name --sort-by='kind' > ${temp_dir}/cp4d-resources.out

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
                oc delete -n ${INSTANCE_NS} ${CR} ${CR_NAME} --wait=false --ignore-not-found
                oc patch -n ${INSTANCE_NS} ${CR}/${CR_NAME} --type=merge -p '{"metadata": {"finalizers":null}}' 2> /dev/null
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
                oc delete -n ${INSTANCE_NS} ${CR} ${CR_NAME} --wait=false --ignore-not-found
                oc patch -n ${INSTANCE_NS} ${CR}/${CR_NAME} --type=merge -p '{"metadata": {"finalizers":null}}' 2> /dev/null
                resource_deleted=true
                ;;
                *)
                ;;
            esac
        done < ${temp_dir}/cp4d-resources.out

        log "Delete role binding if Cloud Pak for Data was connected to IAM"
        oc delete rolebinding -n ${INSTANCE_NS} admin --ignore-not-found --wait=false
        oc patch -n ${INSTANCE_NS} rolebinding/admin --type=merge -p '{"metadata": {"finalizers":null}}' 2> /dev/null
        oc delete authentication.operator.ibm.com -n ${INSTANCE_NS} example-authentication --ignore-not-found --wait=false
        oc patch -n ${INSTANCE_NS} authentication.operator.ibm.com/example-authentication --type=merge -p '{"metadata": {"finalizers":null}}' 2> /dev/null

        #
        # Now the CP4D project should be empty and can be deleted, this may take a while (5-15 minutes)
        #
        force_remove_finalizers ${INSTANCE_NS}
        wait_ns_deleted ${INSTANCE_NS}
    else
        echo "Project ${INSTANCE_NS} does not exist, skipping"
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

delete_knative() {
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
        force_remove_finalizers ${KNATIVE_EVENTING}
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
        force_remove_finalizers ${KNATIVE_SERVING}
        wait_ns_deleted ${KNATIVE_SERVING}
    else
        echo "Project ${KNATIVE_SERVING} does not exist, skipping"
    fi
}

delete_app_connect() {
    APP_CONNECT=ibm-app-connect
    oc get project ${APP_CONNECT} > /dev/null 2>&1
    if [ $? -eq 0 ];then
        log "Deleting everything in the ${APP_CONNECT} project"

        log "Deleting ${APP_CONNECT} project"
        oc delete ns ${APP_CONNECT} --ignore-not-found --wait=false
        force_remove_finalizers ${APP_CONNECT}
        wait_ns_deleted ${APP_CONNECT}
    else
        echo "Project ${APP_CONNECT} does not exist, skipping"
    fi
}

delete_ibm_scheduler() {
    PROJECT_SCHEDULING_SERVICE=${PROJECT_SCHEDULING_SERVICE:-cpd-scheduler}
    oc get project ${PROJECT_SCHEDULING_SERVICE} > /dev/null 2>&1
    if [ $? -eq 0 ];then
        log "Deleting everything in the ${PROJECT_SCHEDULING_SERVICE} project"
        oc delete Scheduling  -n ${PROJECT_SCHEDULING_SERVICE} --all --ignore-not-found
        oc delete subscriptions.operators.coreos.com -n ${PROJECT_SCHEDULING_SERVICE} --all --ignore-not-found
        oc delete clusterserviceversions.operators.coreos.com -n ${PROJECT_SCHEDULING_SERVICE} --all --ignore-not-found

        log "Deleting ${PROJECT_SCHEDULING_SERVICE} project"
        oc delete ns ${PROJECT_SCHEDULING_SERVICE} --ignore-not-found --wait=false
        force_remove_finalizers ${PROJECT_SCHEDULING_SERVICE}
        wait_ns_deleted ${PROJECT_SCHEDULING_SERVICE}
    else
        echo "Project ${PROJECT_SCHEDULING_SERVICE} does not exist, skipping"
    fi
}

delete_ibm_license_server() {
    check_shared_resources ibmlicensingdefinition.operator.ibm.com ibm-licensing DELETE_LICENSING
    if [ "${DELETE_LICENSING}" -eq 1 ]; then
        IBM_LICENSING=ibm-licensing
        oc get project ${IBM_LICENSING} > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            log "Deleting everything in the ${IBM_LICENSING} project"
            oc delete ibmlicensing  --all --ignore-not-found
            oc delete subscriptions.operators.coreos.com -n ${IBM_LICENSING} --all --ignore-not-found
            oc delete clusterserviceversions.operators.coreos.com -n ${IBM_LICENSING} --all --ignore-not-found

            log "Deleting ${IBM_LICENSING} project"
            oc delete ns ${IBM_LICENSING} --ignore-not-found --wait=false
            force_remove_finalizers ${IBM_LICENSING}
            wait_ns_deleted ${IBM_LICENSING}
        else
            echo "Project ${IBM_LICENSING} does not exist, skipping"
        fi
    else
        echo "Keeping ${IBM_LICENSING} namespace due to shared resources"
    fi
}

delete_ibm_certificate_manager() {
    check_shared_resources certificaterequests.cert-manager.io ibm-cert-manager DELETE_CERT_MANAGER
    if [ "${DELETE_CERT_MANAGER}" -eq 1 ]; then
        IBM_CERT_MANAGER=ibm-cert-manager
        oc get project ${IBM_CERT_MANAGER} > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            log "Deleting everything in the ${IBM_CERT_MANAGER} project"
            oc delete lease -n ${IBM_CERT_MANAGER} --all --ignore-not-found
            oc delete endpointslice -n ${IBM_CERT_MANAGER}  --all --ignore-not-found
            oc delete endpoints -n ${IBM_CERT_MANAGER}  --all --ignore-not-found

            oc delete subscriptions.operators.coreos.com -n ${IBM_CERT_MANAGER} --all --ignore-not-found
            oc delete clusterserviceversions.operators.coreos.com -n ${IBM_CERT_MANAGER} --all --ignore-not-found

            log "Deleting ${IBM_CERT_MANAGER} project"
            oc delete ns ${IBM_CERT_MANAGER} --ignore-not-found --wait=false
            force_remove_finalizers ${IBM_CERT_MANAGER}
            wait_ns_deleted ${IBM_CERT_MANAGER}
        else
            echo "Project ${IBM_CERT_MANAGER} does not exist, skipping"
        fi
    else
        echo "Keeping ${IBM_CERT_MANAGER} namespace due to shared resources"
    fi
}

delete_common_services_control() {
    IBM_CS_CONTROL=cs-control
    oc get project ${IBM_CS_CONTROL} > /dev/null 2>&1
    if [ $? -eq 0 ];then
        log "Deleting everything in the ${IBM_CS_CONTROL} project"
        oc delete nss -n ${IBM_CS_CONTROL} --all --ignore-not-found

        log "Deleting ${IBM_CS_CONTROL} project"
        oc delete ns ${IBM_CS_CONTROL} --ignore-not-found --wait=false
        force_remove_finalizers ${IBM_CS_CONTROL}
        wait_ns_deleted ${IBM_CS_CONTROL}
    else
        echo "Project ${IBM_CS_CONTROL} does not exist, skipping"
    fi
}

delete_cluster_wide_cr_config() {
    # Delete other elements belonging to CP4D install
    echo "Deleting MutatingWebhookConfigurations"
    oc delete MutatingWebhookConfiguration ibm-common-service-webhook-configuration --ignore-not-found
    oc delete MutatingWebhookConfiguration ibm-operandrequest-webhook-configuration --ignore-not-found
    oc delete MutatingWebhookConfiguration ibm-operandrequest-webhook-configuration-${OPERATOR_NS} --ignore-not-found
    oc delete MutatingWebhookConfiguration postgresql-operator-mutating-webhook-configuration-${OPERATOR_NS} --ignore-not-found

    echo "Deleting ValidatingWebhookConfiguration"
    oc delete ValidatingWebhookConfiguration ibm-common-service-validating-webhook-cpd-operators --ignore-not-found
    oc delete ValidatingWebhookConfiguration ibm-cs-ns-mapping-webhook-configuration --ignore-not-found
    oc delete ValidatingWebhookConfiguration postgresql-operator-validating-webhook-configuration-${OPERATOR_NS} --ignore-not-found

    echo "Deleting common-service maps"
    oc delete cm -n kube-public common-service-maps --ignore-not-found
}

delete_ibm_crds() {
    #
    # Delete IBM CRDs that don't have an instance
    #
    log "Deleting IBM CRDs that don't have an instance anymore"
    log "Listing all IBM CRDs still listed by ClusterServiceVersions"
    oc get csv -A -o json | jq -r .items[].status.requirementStatus[].name | grep ibm > /tmp/cp4d-delete-instance-csvs.out
    for crd in $(oc get crd --no-headers | awk '{print $1}' | grep -E '\.ibm|mantaflows\.adl');do
        if [[ "$(oc get ${crd} --no-headers -A 2>/dev/null)" != "" ]] ;then
            log "Not deleting CRD ${crd}, still has some instances"
        elif grep -q ${crd} /tmp/cp4d-delete-instance-csvs.out;then
            log "Not deleting CRD ${crd}, which is still referred to be a ClusterServiceVersion"
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
}

#
# MAIN CODE
#

# Ask for final confirmation to delete the CP4D instance
if [ -z "${CPD_CONFIRM_DELETE}" ];then
    echo "About to delete the following from the cluster:"
    if oc get project ${INSTANCE_NS} > /dev/null 2>&1;then echo "- Instance namespace: ${INSTANCE_NS}";fi
    if oc get project ${OPERATOR_NS} > /dev/null 2>&1;then echo "- Operator namespace: ${OPERATOR_NS}";fi
    if oc get project ibm-app-connect > /dev/null 2>&1;then echo "- Knative events: ibm-app-connect";fi
    if oc get project ibm-knative-events > /dev/null 2>&1;then echo "- Knative events: ibm-knative-events";fi
    if oc get project knative-serving > /dev/null 2>&1;then echo "- Knative server: knative-serving";fi
    if oc get project ibm-licensing > /dev/null 2>&1;then echo "- License manager namespace: ibm-licensing";fi
    if oc get project ${PROJECT_SCHEDULING_SERVICE:-cpd-scheduler} > /dev/null 2>&1;then echo "- Scheduler namespace: ${PROJECT_SCHEDULING_SERVICE:-cpd-scheduler}";fi
    if oc get project ibm-cert-manager > /dev/null 2>&1;then echo "- Certificate manager: ibm-cert-manager";fi
    if oc get project cs-control > /dev/null 2>&1;then echo "- Common Services control: cs-control";fi
    echo "- IBM Custom Resource Definitions"
    read -p "Are you sure (y/N)? " -r
    case "${REPLY}" in 
    y|Y)
    ;;
    * )
    exit 99
    ;;
    esac
fi

# By default destroy the cluster-wide resources
if [ -z "${CPD_DESTROY_CLUSTER_WIDE}" ];then
    CPD_DESTROY_CLUSTER_WIDE=true
else
    CPD_DESTROY_CLUSTER_WIDE=false
fi

# Create temporary directory
temp_dir=$(mktemp -d)

# Delete Cloud Pak for Data instance
delete_instance_ns ${INSTANCE_NS}

# Delete operators in new operators namespace
delete_operator_ns ${OPERATOR_NS}

# If cluster-wide resources must be destroyed, do so
if ${CPD_DESTROY_CLUSTER_WIDE};then
    # Delete KNative operator and project
    delete_knative

    # Delete App Connect
    delete_app_connect

    # Delete IBM Scheduler
    delete_ibm_scheduler

    # Delete IBM License Server
    delete_ibm_license_server

    # Delete certifiate manager
    delete_ibm_certificate_manager

    # Delete old version of certifiate manager and license manager
    delete_common_services_control

    # Delete cluster-wide CRs and config
    delete_cluster_wide_cr_config

    # Delete IBM CRDs
    delete_ibm_crds
fi

exit 0