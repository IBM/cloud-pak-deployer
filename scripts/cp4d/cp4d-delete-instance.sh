#!/bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

command_usage() {
  cat << EOF

Cloud Pak for Data Instance Deletion Script
============================================

USAGE:
  $(basename $0) <NAMESPACE>        # Delete specific instance (REQUIRED)
  $(basename $0) -n <NS> [OPTIONS]  # Delete with options

REQUIRED:
  <NAMESPACE> or -n <NAMESPACE>  CP4D instance namespace (e.g., cpd, zen)

COMMON OPTIONS:
  --operator-ns <NS>     Operator namespace (default: <instance>-operators)
  --scheduler-ns <NS>    Scheduler namespace (if different from auto-detected)
  --dry-run              Show what would be deleted (safe, no changes)
  --sequential           Use sequential deletion (slower, default is parallel)
  --force-finalizer      Force cleanup of stuck resources
  --timeout <SECONDS>    Deletion timeout (default: 900)
  -h, --help            Show this help

ENVIRONMENT VARIABLES (optional):
  PROJECT_CERT_MANAGER        Certificate manager namespace
  PROJECT_LICENSE_SERVICE     License service namespace
  PROJECT_SCHEDULING_SERVICE  Scheduler namespace

EXAMPLES:
  # Safe test - see what would be deleted
  $(basename $0) cpd --dry-run

  # Delete instance with default operator namespace (cpd-operators)
  $(basename $0) cpd

  # Delete with custom operator namespace
  $(basename $0) cpd --operator-ns my-operators

  # Sequential deletion (slower but more controlled)
  $(basename $0) cpd --sequential

  # Fast deletion with forced cleanup
  $(basename $0) cpd --force-finalizer

WHAT GETS DELETED:
  • CP4D instance namespace (specified)
  • Operator namespace (default: <instance>-operators)
  • IBM scheduler namespace (if found)
  • IBM licensing namespace (if not shared with other instances)
  • IBM cert-manager namespace (if not shared with other instances)
  • Knative services (if present)
  • IBM CRDs and webhooks

NOTES:
  ⚠  This operation is IRREVERSIBLE
  ✓  Always test with --dry-run first
  ✓  Requires cluster-admin permissions
  ✓  Instance namespace MUST be specified explicitly

EOF
  exit $1
}

# Color codes for output
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_CYAN='\033[0;36m'
COLOR_RESET='\033[0m'

get_logtime() {
  echo $(date "+%Y-%m-%d %H:%M:%S")
}

log() {
  LOG_TIME=$(get_logtime)
  printf "[${LOG_TIME}] ${1}\n"
}

log_success() {
  LOG_TIME=$(get_logtime)
  printf "${COLOR_GREEN}✓ [${LOG_TIME}] ${1}${COLOR_RESET}\n"
}

log_error() {
  LOG_TIME=$(get_logtime)
  printf "${COLOR_RED}✗ [${LOG_TIME}] ${1}${COLOR_RESET}\n"
}

log_warning() {
  LOG_TIME=$(get_logtime)
  printf "${COLOR_YELLOW}⚠ [${LOG_TIME}] ${1}${COLOR_RESET}\n"
}

log_info() {
  LOG_TIME=$(get_logtime)
  printf "${COLOR_CYAN}ℹ [${LOG_TIME}] ${1}${COLOR_RESET}\n"
}

#
# DISCOVERY FUNCTIONS FOR SUPPORTING SERVICES
#
discover_supporting_services() {
    log_info "Discovering supporting services..."
    
    # Discover scheduler namespace if not provided
    if [ -z "${PROJECT_SCHEDULING_SERVICE}" ]; then
        local scheduler_ns=$(oc get scheduling --all-namespaces --no-headers 2>/dev/null | head -1 | awk '{print $1}')
        if [ -n "$scheduler_ns" ]; then
            # Verify it's IBM scheduler
            if [[ "$scheduler_ns" =~ ^(cpd-scheduler|ibm-scheduler|.*-cpd-scheduler)$ ]]; then
                log_success "Discovered IBM scheduler namespace: ${scheduler_ns}"
                export PROJECT_SCHEDULING_SERVICE="${scheduler_ns}"
            fi
        else
            log_info "No IBM scheduler namespace found"
        fi
    fi
    
    # Discover cert-manager namespace if not provided
    if [ -z "${PROJECT_CERT_MANAGER}" ]; then
        if oc get project ibm-cert-manager > /dev/null 2>&1; then
            export PROJECT_CERT_MANAGER="ibm-cert-manager"
            log_success "Discovered IBM cert-manager namespace: ibm-cert-manager"
        else
            log_info "No IBM cert-manager namespace found"
        fi
    fi
    
    # Discover licensing namespace if not provided
    if [ -z "${PROJECT_LICENSE_SERVICE}" ]; then
        if oc get project ibm-licensing > /dev/null 2>&1; then
            export PROJECT_LICENSE_SERVICE="ibm-licensing"
            log_success "Discovered IBM licensing namespace: ibm-licensing"
        else
            log_info "No IBM licensing namespace found"
        fi
    fi
}

#
# PARSE ARGUMENTS
#
if [ "$#" -eq 0 ]; then
    log_error "Instance namespace is required"
    echo
    command_usage 1
elif [ "$#" -eq 1 ] && [ "$1" != "--help" ] && [ "$1" != "-h" ] && [ "$1" != "--dry-run" ] && [ "$1" != "--sequential" ];then
    # Single argument that's not a flag - treat as instance namespace
    export INSTANCE_NS=$1
else
    # Check if first argument is a namespace (doesn't start with -)
    if [ -n "$1" ] && [ "${1:0:1}" != "-" ]; then
        export INSTANCE_NS=$1
        shift 1
    fi
    
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
        elif [ -n "$2" ] && [ ${2:0:1} != "-" ];then
            export OPERATOR_NS=$2
            shift 2
        else
            echo "Error: Missing operator namespace argument."
            command_usage 2
        fi
        ;;
    --scheduler-ns*)
        if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
            export PROJECT_SCHEDULING_SERVICE="${1#*=}"
            shift 1
        elif [ -n "$2" ] && [ ${2:0:1} != "-" ];then
            export PROJECT_SCHEDULING_SERVICE=$2
            shift 2
        else
            echo "Error: Missing scheduler namespace argument."
            command_usage 2
        fi
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
    --sequential)
        export SEQUENTIAL_DELETE=true
        shift 1
        ;;
    --dry-run)
        export DRY_RUN=true
        shift 1
        ;;
    *) # preserve remaining arguments
        PARAMS="$PARAMS $1"
        shift
        ;;
    esac
    done
fi

# Validate that instance namespace is provided and not empty
if [ -z "${INSTANCE_NS}" ]; then
    log_error "Instance namespace is required but not provided"
    echo
    echo "Please specify the CP4D instance namespace:"
    echo "  $(basename $0) <instance-namespace>"
    echo
    echo "Example:"
    echo "  $(basename $0) cpd"
    echo
    echo "To find your CP4D instance namespace, run:"
    echo "  oc get zenservice --all-namespaces"
    echo
    exit 1
fi

# Validate namespace is not empty string
if [ "${INSTANCE_NS}" = "" ]; then
    log_error "Instance namespace cannot be an empty string"
    exit 1
fi

# Set operator namespace if not specified
if [ -z "${OPERATOR_NS}" ]; then
    export OPERATOR_NS="${INSTANCE_NS}-operators"
    log_info "Operator namespace not specified, using default: ${OPERATOR_NS}"
fi

# Discover supporting services (scheduler, cert-manager, licensing)
discover_supporting_services

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
            log_warning "Timeout reached waiting for namespace ${NS} deletion after ${TIMEOUT}s"
            log_warning "Namespace ${NS} may still be in Terminating state"
            
            # Run diagnostics
            diagnose_namespace_stuck ${NS}
            
            if [ "${FORCE_FINALIZER}" = "true" ] && [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
                RETRY_COUNT=$((RETRY_COUNT + 1))
                log_info "Attempting forced cleanup (attempt ${RETRY_COUNT}/${MAX_RETRIES})..."
                force_remove_finalizers ${NS}
                
                # Reset timeout for retry
                ELAPSED=0
                TIMEOUT=300  # Shorter timeout for retries
                log "Waiting additional ${TIMEOUT}s after forced cleanup..."
                continue
            else
                log_error "Failed to delete namespace ${NS} after ${MAX_RETRIES} retry attempts"
                return 1
            fi
        fi
        
        # Log progress every 60 seconds
        if [ $((ELAPSED % 60)) -eq 0 ] && [ $ELAPSED -gt 0 ]; then
            log "Still waiting for ${NS} deletion... (${ELAPSED}s elapsed)"
        fi
    done
    log_success "Project ${NS} deleted successfully"
    return 0
}

# Start namespace deletion in background (non-blocking)
start_ns_deletion() {
    NS=$1
    log_info "Starting deletion of namespace ${NS} in background..."
    oc delete ns ${NS} --ignore-not-found --wait=false 2>&1 | sed "s/^/[${NS}] /" &
}

# Wait for multiple namespaces to be deleted in parallel
wait_multiple_ns_deleted() {
    local namespaces=("$@")
    local timeout=${NAMESPACE_DELETE_TIMEOUT:-900}
    local start_time=$(date +%s)
    local all_deleted=false
    
    log_info "Waiting for ${#namespaces[@]} namespaces to be deleted in parallel..."
    
    while [ "$all_deleted" = false ]; do
        all_deleted=true
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        # Check if timeout reached
        if [ $elapsed -ge $timeout ]; then
            log_warning "Timeout reached after ${timeout}s"
            break
        fi
        
        # Check each namespace
        for ns in "${namespaces[@]}"; do
            if oc get ns ${ns} > /dev/null 2>&1; then
                all_deleted=false
            fi
        done
        
        if [ "$all_deleted" = false ]; then
            sleep 5
            # Log progress every 60 seconds
            if [ $((elapsed % 60)) -eq 0 ] && [ $elapsed -gt 0 ]; then
                local remaining=()
                for ns in "${namespaces[@]}"; do
                    if oc get ns ${ns} > /dev/null 2>&1; then
                        remaining+=("$ns")
                    fi
                done
                log_info "Still waiting for ${#remaining[@]} namespace(s): ${remaining[*]} (${elapsed}s elapsed)"
            fi
        fi
    done
    
    # Check final status and apply force cleanup if needed
    local failed_ns=()
    for ns in "${namespaces[@]}"; do
        if oc get ns ${ns} > /dev/null 2>&1; then
            failed_ns+=("$ns")
            log_warning "Namespace ${ns} still exists after timeout"
            if [ "${FORCE_FINALIZER}" = "true" ]; then
                log_info "Applying forced cleanup to ${ns}..."
                force_remove_finalizers ${ns}
            fi
        else
            log_success "Namespace ${ns} deleted successfully"
        fi
    done
    
    # If there are failed namespaces and force finalizer is enabled, wait a bit more
    if [ ${#failed_ns[@]} -gt 0 ] && [ "${FORCE_FINALIZER}" = "true" ]; then
        log_info "Waiting additional 120s for forced cleanup to complete..."
        sleep 120
        
        for ns in "${failed_ns[@]}"; do
            if oc get ns ${ns} > /dev/null 2>&1; then
                log_error "Namespace ${ns} still exists after forced cleanup"
            else
                log_success "Namespace ${ns} deleted after forced cleanup"
            fi
        done
    fi
}

force_remove_finalizers() {
    NS=$1
    if [ "${FORCE_FINALIZER}" = "true" ]; then
        log_info "Force removing finalizers for ${NS} namespace"
        
        # First, try to remove finalizers from blocking resources
        force_remove_resource_finalizers ${NS}
        
        # Then remove namespace finalizers using oc patch
        if oc get ns ${NS} > /dev/null 2>&1; then
            log_info "Removing finalizers from namespace ${NS}..."
            oc patch ns ${NS} --type=merge -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
            log_success "Namespace finalizers removed for ${NS}"
        fi
    fi
}

force_remove_resource_finalizers() {
    NS=$1
    log_info "Checking for resources with finalizers in namespace ${NS}..."
    
    # Remove finalizers from PVCs (often block namespace deletion)
    if oc get pvc -n ${NS} --no-headers 2>/dev/null | grep -q .; then
        log_info "Removing finalizers from PVCs in ${NS}..."
        for pvc in $(oc get pvc -n ${NS} --no-headers 2>/dev/null | awk '{print $1}'); do
            oc patch pvc/${pvc} -n ${NS} --type=merge -p '{"metadata": {"finalizers":null}}' 2>/dev/null
        done
    fi
    
    # Remove finalizers from PVs associated with the namespace
    if oc get pv --no-headers 2>/dev/null | grep ${NS} | grep -q .; then
        log_info "Removing finalizers from PVs associated with ${NS}..."
        for pv in $(oc get pv --no-headers 2>/dev/null | grep ${NS} | awk '{print $1}'); do
            oc patch pv/${pv} --type=merge -p '{"metadata": {"finalizers":null}}' 2>/dev/null
        done
    fi
    
    # Remove finalizers from Pods stuck in Terminating
    if oc get pods -n ${NS} --field-selector=status.phase=Terminating --no-headers 2>/dev/null | grep -q .; then
        log_warning "Force deleting Terminating pods in ${NS}..."
        for pod in $(oc get pods -n ${NS} --field-selector=status.phase=Terminating --no-headers 2>/dev/null | awk '{print $1}'); do
            oc delete pod/${pod} -n ${NS} --grace-period=0 --force 2>/dev/null
        done
    fi
    
    # Remove finalizers from Services
    if oc get svc -n ${NS} --no-headers 2>/dev/null | grep -q .; then
        log_info "Removing finalizers from Services in ${NS}..."
        for svc in $(oc get svc -n ${NS} --no-headers 2>/dev/null | awk '{print $1}'); do
            oc patch svc/${svc} -n ${NS} --type=merge -p '{"metadata": {"finalizers":null}}' 2>/dev/null
        done
    fi
    
    # Remove finalizers from ConfigMaps with finalizers
    if oc get cm -n ${NS} --no-headers 2>/dev/null | grep -q .; then
        for cm in $(oc get cm -n ${NS} -o json 2>/dev/null | jq -r '.items[] | select(.metadata.finalizers != null) | .metadata.name'); do
            if [ ! -z "$cm" ]; then
                log_info "Removing finalizers from ConfigMap ${cm} in ${NS}..."
                oc patch cm/${cm} -n ${NS} --type=merge -p '{"metadata": {"finalizers":null}}' 2>/dev/null
            fi
        done
    fi
    
    # Remove finalizers from Secrets with finalizers
    if oc get secret -n ${NS} --no-headers 2>/dev/null | grep -q .; then
        for secret in $(oc get secret -n ${NS} -o json 2>/dev/null | jq -r '.items[] | select(.metadata.finalizers != null) | .metadata.name'); do
            if [ ! -z "$secret" ]; then
                log_info "Removing finalizers from Secret ${secret} in ${NS}..."
                oc patch secret/${secret} -n ${NS} --type=merge -p '{"metadata": {"finalizers":null}}' 2>/dev/null
            fi
        done
    fi
}

diagnose_namespace_stuck() {
    NS=$1
    log_warning "=== Diagnostic information for stuck namespace ${NS} ==="
    
    # Check for resources still in the namespace
    log_info "Resources still present in namespace:"
    oc api-resources --verbs=list --namespaced -o name 2>/dev/null | \
        xargs -I {} sh -c "oc get {} -n ${NS} --ignore-not-found --no-headers 2>/dev/null | head -5" | \
        grep -v "^$" || log "No resources found"
    
    # Check namespace status
    log_info "Namespace status:"
    oc get ns ${NS} -o json 2>/dev/null | jq -r '.status' || log "Cannot get namespace status"
    
    # Check for finalizers on namespace
    log_info "Namespace finalizers:"
    oc get ns ${NS} -o json 2>/dev/null | jq -r '.metadata.finalizers[]' || log "No finalizers found"
    
    # Check for stuck pods
    log_info "Pods in Terminating state:"
    oc get pods -n ${NS} --field-selector=status.phase=Terminating 2>/dev/null || log "No terminating pods"
    
    # Check for PVCs
    log_info "PersistentVolumeClaims:"
    oc get pvc -n ${NS} 2>/dev/null || log "No PVCs found"
    
    log_warning "=== End diagnostic information ==="
}

delete_operator_ns() {
    CP4D_OPERATORS=$1
    
    # Check if namespace exists
    local ns_exists=false
    if oc get project ${CP4D_OPERATORS} > /dev/null 2>&1; then
        ns_exists=true
        log "Operator namespace ${CP4D_OPERATORS} exists, proceeding with deletion"
    else
        log_warning "Operator namespace ${CP4D_OPERATORS} does not exist (may have been deleted or is orphaned)"
        log_info "Will attempt to clean up any remaining operator resources"
    fi

    if [ "$ns_exists" = "true" ]; then
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
        log_info "Skipping operator namespace-specific cleanup (namespace does not exist)"
    fi
    
    # Clean up any orphaned operator resources (CSVs, subscriptions, etc.)
    log_info "Cleaning up any cluster-wide operator resources for ${CP4D_OPERATORS}"
    oc delete csv -A -l "operators.coreos.com/ibm-cpd-platform-operator.${CP4D_OPERATORS}" --ignore-not-found 2>/dev/null || true
    oc delete subscription -A -l "operators.coreos.com/ibm-cpd-platform-operator.${CP4D_OPERATORS}" --ignore-not-found 2>/dev/null || true
}

delete_instance_ns() {
    INSTANCE_NS=$1
    
    # Check if namespace exists
    local ns_exists=false
    if oc get project ${INSTANCE_NS} > /dev/null 2>&1; then
        ns_exists=true
        log "Instance namespace ${INSTANCE_NS} exists, proceeding with deletion"
    else
        log_warning "Instance namespace ${INSTANCE_NS} does not exist (may have been deleted or is orphaned)"
        log_info "Will attempt to clean up any remaining cluster-wide resources"
    fi

    if [ "$ns_exists" = "true" ]; then
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
        log_info "Skipping namespace-specific cleanup (namespace does not exist)"
    fi
    
    # Always attempt to clean up cluster-wide resources related to this instance
    log_info "Cleaning up any cluster-wide resources for instance ${INSTANCE_NS}"
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
    # Only delete IBM cert-manager, never Red Hat cert-manager
    IBM_CERT_MANAGER=${PROJECT_CERT_MANAGER:-ibm-cert-manager}
    
    # Protect Red Hat cert-manager namespace
    if [ "${IBM_CERT_MANAGER}" = "cert-manager" ]; then
        log_warning "Skipping Red Hat cert-manager namespace (protected)"
        return 0
    fi
    
    # Only proceed if it's IBM cert-manager
    if [ "${IBM_CERT_MANAGER}" != "ibm-cert-manager" ]; then
        log_info "Certificate manager namespace '${IBM_CERT_MANAGER}' is not IBM-managed, skipping"
        return 0
    fi
    
    check_shared_resources certificaterequests.cert-manager.io ibm-cert-manager DELETE_CERT_MANAGER
    if [ "${DELETE_CERT_MANAGER}" -eq 1 ]; then
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
            log_info "Project ${IBM_CERT_MANAGER} does not exist, skipping"
        fi
    else
        log_info "Keeping ${IBM_CERT_MANAGER} namespace due to shared resources"
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

# DRY RUN MODE - Just show what would be deleted and exit
if [ "${DRY_RUN}" = "true" ]; then
    log_info "=== DRY RUN MODE - Discovery Only ==="
    echo
    echo "The following namespaces and resources would be deleted:"
    echo
    if oc get project ${INSTANCE_NS} > /dev/null 2>&1;then
        echo "✓ Instance namespace: ${INSTANCE_NS}"
        echo "  Resources: $(oc get zenservice -n ${INSTANCE_NS} --no-headers 2>/dev/null | wc -l) ZenService(s)"
    else
        echo "✗ Instance namespace: ${INSTANCE_NS} (not found)"
    fi
    
    if oc get project ${OPERATOR_NS} > /dev/null 2>&1;then
        echo "✓ Operator namespace: ${OPERATOR_NS}"
        echo "  Operators: $(oc get csv -n ${OPERATOR_NS} --no-headers 2>/dev/null | wc -l) CSV(s)"
    else
        echo "✗ Operator namespace: ${OPERATOR_NS} (not found)"
    fi
    
    if oc get project ibm-app-connect > /dev/null 2>&1;then
        echo "✓ App Connect namespace: ibm-app-connect"
    fi
    
    if oc get project ibm-knative-events > /dev/null 2>&1;then
        echo "✓ Knative events namespace: ibm-knative-events"
    fi
    
    if oc get project knative-eventing > /dev/null 2>&1;then
        echo "✓ Knative eventing namespace: knative-eventing"
    fi
    
    if oc get project knative-serving > /dev/null 2>&1;then
        echo "✓ Knative serving namespace: knative-serving"
    fi
    
    if oc get project ibm-licensing > /dev/null 2>&1;then
        echo "✓ License manager namespace: ibm-licensing"
    fi
    
    if oc get project ${PROJECT_SCHEDULING_SERVICE:-cpd-scheduler} > /dev/null 2>&1;then
        echo "✓ Scheduler namespace: ${PROJECT_SCHEDULING_SERVICE:-cpd-scheduler}"
    fi
    
    if oc get project ibm-cert-manager > /dev/null 2>&1;then
        echo "✓ Certificate manager namespace: ibm-cert-manager"
    fi
    
    if oc get project cert-manager > /dev/null 2>&1;then
        echo "✓ Certificate manager namespace: cert-manager"
    fi
    
    if oc get project cs-control > /dev/null 2>&1;then
        echo "✓ Common Services control namespace: cs-control"
    fi
    
    echo
    echo "Cluster-wide resources:"
    echo "  - MutatingWebhookConfigurations (IBM)"
    echo "  - ValidatingWebhookConfigurations (IBM)"
    echo "  - IBM Custom Resource Definitions"
    
    ibm_crds=$(oc get crd --no-headers 2>/dev/null | awk '{print $1}' | grep -E '\.ibm|mantaflows\.adl' | wc -l)
    echo "  - Total IBM CRDs: ${ibm_crds}"
    
    echo
    log_success "DRY RUN complete - no resources were deleted"
    echo
    echo "To actually delete these resources, run without --dry-run flag"
    exit 0
fi

# Ask for final confirmation to delete the CP4D instance
if [ -z "${CPD_CONFIRM_DELETE}" ];then
    echo
    echo "=========================================="
    echo "  CLOUD PAK FOR DATA DELETION SUMMARY"
    echo "=========================================="
    echo
    echo "The following namespaces will be DELETED:"
    echo
    
    # Core CP4D namespaces
    echo "📦 CORE CP4D NAMESPACES:"
    if oc get project ${INSTANCE_NS} > /dev/null 2>&1;then
        zenservices=$(oc get zenservice -n ${INSTANCE_NS} --no-headers 2>/dev/null | wc -l)
        echo "  ✓ ${INSTANCE_NS} (Instance - ${zenservices} ZenService(s))"
    else
        echo "  ✗ ${INSTANCE_NS} (not found)"
    fi
    
    if oc get project ${OPERATOR_NS} > /dev/null 2>&1;then
        csvs=$(oc get csv -n ${OPERATOR_NS} --no-headers 2>/dev/null | wc -l)
        echo "  ✓ ${OPERATOR_NS} (Operators - ${csvs} CSV(s))"
    else
        echo "  ✗ ${OPERATOR_NS} (not found)"
    fi
    
    # Supporting services
    echo
    echo "🔧 SUPPORTING SERVICES:"
    found_services=false
    
    if oc get project ${PROJECT_SCHEDULING_SERVICE:-cpd-scheduler} > /dev/null 2>&1;then
        echo "  ✓ ${PROJECT_SCHEDULING_SERVICE:-cpd-scheduler} (Scheduler)"
        found_services=true
    fi
    
    if oc get project ibm-licensing > /dev/null 2>&1;then
        echo "  ✓ ibm-licensing (License Manager)"
        found_services=true
    fi
    
    if oc get project ibm-cert-manager > /dev/null 2>&1;then
        echo "  ✓ ibm-cert-manager (Certificate Manager)"
        found_services=true
    elif oc get project cert-manager > /dev/null 2>&1;then
        echo "  ✓ cert-manager (Certificate Manager)"
        found_services=true
    fi
    
    if oc get project cs-control > /dev/null 2>&1;then
        echo "  ✓ cs-control (Common Services Control)"
        found_services=true
    fi
    
    if [ "$found_services" = false ]; then
        echo "  (none found)"
    fi
    
    # Knative services
    echo
    echo "🌐 KNATIVE SERVICES:"
    found_knative=false
    
    if oc get project ibm-app-connect > /dev/null 2>&1;then
        echo "  ✓ ibm-app-connect"
        found_knative=true
    fi
    
    if oc get project ibm-knative-events > /dev/null 2>&1;then
        echo "  ✓ ibm-knative-events"
        found_knative=true
    fi
    
    if oc get project knative-eventing > /dev/null 2>&1;then
        echo "  ✓ knative-eventing"
        found_knative=true
    fi
    
    if oc get project knative-serving > /dev/null 2>&1;then
        echo "  ✓ knative-serving"
        found_knative=true
    fi
    
    if [ "$found_knative" = false ]; then
        echo "  (none found)"
    fi
    
    # Cluster-wide resources
    echo
    echo "🌍 CLUSTER-WIDE RESOURCES:"
    ibm_crds=$(oc get crd --no-headers 2>/dev/null | awk '{print $1}' | grep -E '\.ibm|mantaflows\.adl' | wc -l)
    echo "  ✓ IBM Custom Resource Definitions (${ibm_crds} CRDs)"
    echo "  ✓ MutatingWebhookConfigurations (IBM)"
    echo "  ✓ ValidatingWebhookConfigurations (IBM)"
    
    echo
    echo "=========================================="
    echo
    log_warning "This operation is IRREVERSIBLE!"
    echo
    read -p "Are you absolutely sure you want to DELETE all these resources? (y/N): " -r
    case "${REPLY}" in
    y|Y)
        log_success "Deletion confirmed. Proceeding..."
        echo
    ;;
    * )
        log_info "Deletion cancelled by user"
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

# Parallel deletion is now the default (faster), use --sequential to disable
if [ "${SEQUENTIAL_DELETE}" != "true" ]; then
    log_info "Using parallel deletion mode for faster execution (use --sequential for sequential mode)"
    
    # Delete Cloud Pak for Data instance (must be first)
    delete_instance_ns ${INSTANCE_NS}
    
    # Delete operators in new operators namespace (must be second)
    delete_operator_ns ${OPERATOR_NS}
    
    # If cluster-wide resources must be destroyed, do so in parallel
    if ${CPD_DESTROY_CLUSTER_WIDE};then
        log_info "Starting parallel deletion of cluster-wide namespaces..."
        
        # Collect namespaces to delete in parallel
        parallel_namespaces=()
        
        # Check and prepare knative namespaces
        if oc get project ibm-knative-events > /dev/null 2>&1; then
            delete_operator_ns ibm-knative-events
        fi
        
        if oc get project knative-eventing > /dev/null 2>&1; then
            # Clean up resources first
            oc get --no-headers -n knative-eventing $(oc api-resources --namespaced=true --verbs=list -o name | grep ibm | awk '{printf "%s%s",sep,$0;sep=","}') --ignore-not-found -o=custom-columns=KIND:.kind,NAME:.metadata.name --sort-by='kind' 2>/dev/null | while read -r line; do
                read -r CR CR_NAME <<< "${line}"
                oc delete -n knative-eventing ${CR} ${CR_NAME} --wait=false --ignore-not-found 2>/dev/null
                oc patch -n knative-eventing ${CR}/${CR_NAME} --type=merge -p '{"metadata": {"finalizers":null}}' 2>/dev/null
            done
            start_ns_deletion knative-eventing
            parallel_namespaces+=("knative-eventing")
        fi
        
        if oc get project knative-serving > /dev/null 2>&1; then
            start_ns_deletion knative-serving
            parallel_namespaces+=("knative-serving")
        fi
        
        # App Connect
        if oc get project ibm-app-connect > /dev/null 2>&1; then
            start_ns_deletion ibm-app-connect
            parallel_namespaces+=("ibm-app-connect")
        fi
        
        # Scheduler
        PROJECT_SCHEDULING_SERVICE=${PROJECT_SCHEDULING_SERVICE:-cpd-scheduler}
        if oc get project ${PROJECT_SCHEDULING_SERVICE} > /dev/null 2>&1; then
            oc delete Scheduling -n ${PROJECT_SCHEDULING_SERVICE} --all --ignore-not-found 2>/dev/null
            oc delete subscriptions.operators.coreos.com -n ${PROJECT_SCHEDULING_SERVICE} --all --ignore-not-found 2>/dev/null
            oc delete clusterserviceversions.operators.coreos.com -n ${PROJECT_SCHEDULING_SERVICE} --all --ignore-not-found 2>/dev/null
            start_ns_deletion ${PROJECT_SCHEDULING_SERVICE}
            parallel_namespaces+=("${PROJECT_SCHEDULING_SERVICE}")
        fi
        
        # License Server (if not shared)
        check_shared_resources ibmlicensingdefinition.operator.ibm.com ibm-licensing DELETE_LICENSING
        if [ "${DELETE_LICENSING}" -eq 1 ] && oc get project ibm-licensing > /dev/null 2>&1; then
            oc delete ibmlicensing --all --ignore-not-found 2>/dev/null
            oc delete subscriptions.operators.coreos.com -n ibm-licensing --all --ignore-not-found 2>/dev/null
            oc delete clusterserviceversions.operators.coreos.com -n ibm-licensing --all --ignore-not-found 2>/dev/null
            start_ns_deletion ibm-licensing
            parallel_namespaces+=("ibm-licensing")
        fi
        
        # Certificate Manager (if not shared)
        check_shared_resources certificaterequests.cert-manager.io ibm-cert-manager DELETE_CERT_MANAGER
        if [ "${DELETE_CERT_MANAGER}" -eq 1 ] && oc get project ibm-cert-manager > /dev/null 2>&1; then
            oc delete lease -n ibm-cert-manager --all --ignore-not-found 2>/dev/null
            oc delete endpointslice -n ibm-cert-manager --all --ignore-not-found 2>/dev/null
            oc delete endpoints -n ibm-cert-manager --all --ignore-not-found 2>/dev/null
            oc delete subscriptions.operators.coreos.com -n ibm-cert-manager --all --ignore-not-found 2>/dev/null
            oc delete clusterserviceversions.operators.coreos.com -n ibm-cert-manager --all --ignore-not-found 2>/dev/null
            start_ns_deletion ibm-cert-manager
            parallel_namespaces+=("ibm-cert-manager")
        fi
        
        # Common Services Control
        if oc get project cs-control > /dev/null 2>&1; then
            oc delete nss -n cs-control --all --ignore-not-found 2>/dev/null
            start_ns_deletion cs-control
            parallel_namespaces+=("cs-control")
        fi
        
        # Wait for all parallel deletions to complete
        if [ ${#parallel_namespaces[@]} -gt 0 ]; then
            wait_multiple_ns_deleted "${parallel_namespaces[@]}"
        fi
        
        # Delete cluster-wide CRs and config
        delete_cluster_wide_cr_config
        
        # Delete IBM CRDs
        delete_ibm_crds
    fi
else
    # Sequential deletion (original behavior)
    log_info "Using sequential deletion mode"
    
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
fi

exit 0