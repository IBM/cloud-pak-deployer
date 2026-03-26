#!/bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

command_usage() {
  cat << EOF

Cloud Pak for Data Instance Deletion Script
============================================

This script deletes a Cloud Pak for Data instance and all related resources from an OpenShift cluster.

USAGE:
  $(basename $0)                                    # Auto-discover and delete (with confirmation)
  $(basename $0) --dry-run                          # Show what would be deleted (safe test mode)
  $(basename $0) <INSTANCE_NAMESPACE>               # Delete specific instance
  $(basename $0) -n <NS> [OPTIONS]                  # Delete with options

MODES:
  Auto-Discovery Mode (Recommended):
    $(basename $0)
    - Automatically discovers CP4D namespaces by finding ZenService resources
    - Shows detailed summary of what will be deleted
    - Asks for confirmation before proceeding
    - Safe: requires explicit 'y' to proceed

  Dry-Run Mode (Testing):
    $(basename $0) --dry-run
    - Discovers and displays all CP4D namespaces and resources
    - Does NOT delete anything
    - Perfect for testing discovery or understanding your installation

  Manual Mode (Traditional):
    $(basename $0) cpd
    $(basename $0) -n cpd --operator-ns cpd-operators
    - Specify namespaces explicitly
    - Useful when auto-discovery fails or for specific configurations

OPTIONS:
  -n, --instance-namespace <NS>   Instance namespace (e.g., cpd, zen)
  --operator-ns <NS>              Operator namespace (default: <instance>-operators)
  --auto-discover                 Force auto-discovery mode
  --dry-run                       Show what would be deleted without deleting
  --parallel                      Delete multiple namespaces in parallel (faster)
  --force-finalizer               Force removal of stuck finalizers via API
  --timeout <SECONDS>             Namespace deletion timeout (default: 900)
  -h, --help                      Show this help message

WHAT GETS DELETED:
  • Instance namespace (e.g., cpd) - Contains ZenService and cartridges
  • Operator namespace (e.g., cpd-operators) - Contains operators and CSVs
  • Supporting services: scheduler, licensing, cert-manager
  • Knative services: eventing, serving, app-connect
  • Cluster-wide: IBM CRDs, webhooks, common-service maps

EXAMPLES:
  # Test what would be deleted (safe)
  $(basename $0) --dry-run

  # Delete with auto-discovery (recommended)
  $(basename $0)

  # Delete specific instance
  $(basename $0) -n my-cpd-instance

  # Fast parallel deletion with forced cleanup
  $(basename $0) --parallel --force-finalizer

  # Automated deletion (CI/CD - skips confirmations)
  export CPD_CONFIRM_DELETE=true
  $(basename $0)

ENVIRONMENT VARIABLES:
  CPD_CONFIRM_DELETE          Set to 'true' to skip confirmation prompts
  CPD_DESTROY_CLUSTER_WIDE    Set to 'false' to keep cluster-wide resources
  PROJECT_SCHEDULING_SERVICE  Override scheduler namespace (default: cpd-scheduler)

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
# AUTO-DISCOVERY FUNCTIONS
#
discover_cp4d_namespaces() {
    log_info "Auto-discovering Cloud Pak for Data namespaces..."
    
    # Discover instance namespace by looking for ZenService CR
    local discovered_instance_ns=$(oc get zenservice --all-namespaces --no-headers 2>/dev/null | head -1 | awk '{print $1}')
    
    if [ -z "$discovered_instance_ns" ]; then
        log_warning "Could not auto-discover instance namespace (no ZenService found)"
        return 1
    fi
    
    log_success "Discovered instance namespace: ${discovered_instance_ns}"
    export INSTANCE_NS="${discovered_instance_ns}"
    
    # Try to discover operator namespace
    # Common patterns: <instance>-operators, cpd-operators, ibm-cpd-operators
    local possible_operator_ns=(
        "${INSTANCE_NS}-operators"
        "cpd-operators"
        "ibm-cpd-operators"
        "${INSTANCE_NS}-operator"
    )
    
    for ns in "${possible_operator_ns[@]}"; do
        if oc get project "${ns}" > /dev/null 2>&1; then
            # Verify it has CP4D operators
            if oc get csv -n "${ns}" --no-headers 2>/dev/null | grep -q "ibm-cpd-platform-operator\|ibm-common-service-operator"; then
                log_success "Discovered operator namespace: ${ns}"
                export OPERATOR_NS="${ns}"
                break
            fi
        fi
    done
    
    if [ -z "$OPERATOR_NS" ]; then
        log_warning "Could not auto-discover operator namespace, using default: ${INSTANCE_NS}-operators"
        export OPERATOR_NS="${INSTANCE_NS}-operators"
    fi
    
    # Discover scheduler namespace
    local scheduler_ns=$(oc get scheduling --all-namespaces --no-headers 2>/dev/null | head -1 | awk '{print $1}')
    if [ -n "$scheduler_ns" ]; then
        log_success "Discovered scheduler namespace: ${scheduler_ns}"
        export PROJECT_SCHEDULING_SERVICE="${scheduler_ns}"
    else
        # Try to find namespace containing "scheduler" but exclude OpenShift system namespaces
        scheduler_ns=$(oc get projects --no-headers 2>/dev/null | awk '{print $1}' | grep -i "scheduler" | grep -v "^openshift-" | grep -i "cpd\|ibm" | head -1)
        if [ -n "$scheduler_ns" ]; then
            log_success "Discovered scheduler namespace by pattern: ${scheduler_ns}"
            export PROJECT_SCHEDULING_SERVICE="${scheduler_ns}"
        else
            log_info "No CP4D scheduler namespace found (scheduler not installed or using default OpenShift scheduler)"
        fi
    fi
    
    # Discover cert-manager namespace - try exact names first, then pattern matching
    if oc get project cert-manager > /dev/null 2>&1; then
        export PROJECT_CERT_MANAGER="cert-manager"
        log_success "Discovered cert-manager namespace: cert-manager"
    elif oc get project ibm-cert-manager > /dev/null 2>&1; then
        export PROJECT_CERT_MANAGER="ibm-cert-manager"
        log_success "Discovered cert-manager namespace: ibm-cert-manager"
    else
        # Try pattern matching: look for namespaces containing both "cert" and "manager" or just "cert" with "ibm"
        local cert_ns=$(oc get projects --no-headers 2>/dev/null | awk '{print $1}' | grep -i "cert" | grep -iE "manager|ibm" | head -1)
        if [ -n "$cert_ns" ]; then
            export PROJECT_CERT_MANAGER="${cert_ns}"
            log_success "Discovered cert-manager namespace by pattern: ${cert_ns}"
        fi
    fi
    
    # Discover licensing namespace - try exact name first, then pattern matching
    if oc get project ibm-licensing > /dev/null 2>&1; then
        export PROJECT_LICENSE_SERVICE="ibm-licensing"
        log_success "Discovered licensing namespace: ibm-licensing"
    else
        # Try pattern matching: look for namespaces containing "licensing" or "license" with "ibm"
        local license_ns=$(oc get projects --no-headers 2>/dev/null | awk '{print $1}' | grep -iE "licens" | grep -i "ibm" | head -1)
        if [ -z "$license_ns" ]; then
            # Try just "licensing" or "license" without ibm requirement
            license_ns=$(oc get projects --no-headers 2>/dev/null | awk '{print $1}' | grep -iE "licens" | head -1)
        fi
        if [ -n "$license_ns" ]; then
            export PROJECT_LICENSE_SERVICE="${license_ns}"
            log_success "Discovered licensing namespace by pattern: ${license_ns}"
        fi
    fi
    
    return 0
}

display_discovered_namespaces() {
    echo
    echo "=== Discovered Cloud Pak for Data Configuration ==="
    echo "Instance namespace:   ${INSTANCE_NS:-<not found>}"
    echo "Operator namespace:   ${OPERATOR_NS:-<not found>}"
    echo "Scheduler namespace:  ${PROJECT_SCHEDULING_SERVICE:-<not found>}"
    echo "Cert-manager:         ${PROJECT_CERT_MANAGER:-<not found>}"
    echo "Licensing:            ${PROJECT_LICENSE_SERVICE:-<not found>}"
    echo "=================================================="
    echo
}

#
# PARSE
#
if [ "$#" -eq 0 ]; then
    # No arguments provided, try auto-discovery
    export AUTO_DISCOVER=true
elif [ "$#" -eq 1 ] && [ "$1" != "--help" ] && [ "$1" != "-h" ];then
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
    --parallel)
        export PARALLEL_DELETE=true
        shift 1
        ;;
    --auto-discover)
        export AUTO_DISCOVER=true
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

# Auto-discover namespaces if requested or if no instance namespace provided
if [ "${AUTO_DISCOVER}" = "true" ] || [ -z "${INSTANCE_NS}" ]; then
    if [ "${AUTO_DISCOVER}" = "true" ]; then
        log_info "Auto-discovery mode enabled"
    else
        log_info "No instance namespace provided, attempting auto-discovery..."
    fi
    
    if discover_cp4d_namespaces; then
        display_discovered_namespaces
        # Note: Final confirmation will be asked before deletion with full summary
    else
        log_error "Auto-discovery failed - no Cloud Pak for Data instance found in the cluster"
        echo
        echo "Possible reasons:"
        echo "  1. No CP4D instance is installed (no ZenService found)"
        echo "  2. You don't have permissions to view resources across namespaces"
        echo "  3. The CP4D instance is in a non-standard configuration"
        echo
        echo "Solutions:"
        echo "  • If you know the instance namespace, specify it manually:"
        echo "    $(basename $0) -n <instance-namespace>"
        echo
        echo "  • To see all available namespaces:"
        echo "    oc get projects"
        echo
        echo "  • To check for ZenService resources:"
        echo "    oc get zenservice --all-namespaces"
        echo
        exit 1
    fi
fi

# Ensure OPERATOR_NS is set if INSTANCE_NS is set
if [ -n "${INSTANCE_NS}" ] && [ -z "${OPERATOR_NS}" ]; then
    export OPERATOR_NS="${INSTANCE_NS}-operators"
    log_info "Operator namespace not specified, using default: ${OPERATOR_NS}"
fi

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
    
    local ibm_crds=$(oc get crd --no-headers 2>/dev/null | awk '{print $1}' | grep -E '\.ibm|mantaflows\.adl' | wc -l)
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

if [ "${PARALLEL_DELETE}" = "true" ]; then
    log_info "Using parallel deletion mode for faster execution"
    
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