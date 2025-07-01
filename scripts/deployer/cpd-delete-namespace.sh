#!/bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

command_usage() {
  echo
  echo "Usage: $0 --namespace <NAMESPACE>"
  exit $1
}

#
# PARSE
#
# Parse parameters
PARAMS=""
while (( "$#" )); do
  case "$1" in
  --help|-h)
    command_usage 0
    ;;
  --namespace*|-n*)
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export NAMESPACE="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export NAMESPACE=$2
      shift 2
    else
      echo "Error: Missing namespace for --namespace parameter."
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

get_logtime() {
  echo $(date "+%Y-%m-%d %H:%M:%S")
}

log() {
  LOG_TIME=$(get_logtime)
  printf "[${LOG_TIME}] ${1}\n"
}

list_crs() {
  ${SCRIPT_DIR}/cpd-list-crs.sh -n $1 --no-headers > ${temp_dir}/cpd-list-crs.out
}

wait_ns_deleted() {
    NAMESPACE=$1
    log "Waiting for deletion of namespace ${NAMESPACE} ..."
    while $(oc get ns ${NAMESPACE} > /dev/null 2>&1);do
        sleep 1
    done
    log "Namespace ${NAMESPACE} deleted"
}

delete_ns() {
  NAMESPACE=$1
  log "Deleting everything in the ${NAMESPACE} project ..."

  # Delete namespace at the beginning to avoid additional CRs being created
  oc delete ns ${NAMESPACE} --ignore-not-found --wait=false > /dev/null 

  CRDS=$(cat ${temp_dir}/cpd-list-crs.out | awk '{print $1}' | uniq | awk '{printf "%s%s",sep,$0;sep=","}')

  if [ "${CRDS}" != "" ];then
    log "Deleting all CRs ..."
    oc delete -n ${NAMESPACE} ${CRDS} --all --timeout=30s

    # Patch the CRs to force delete
    log "Patch remaining CRs to force delete ..."
    while read -r line;do
      read -r KIND CR_NAME <<< "${line}"
      oc patch -n ${NAMESPACE} ${KIND}/${CR_NAME} --type=merge -p '{"metadata": {"finalizers":null}}' 2> /dev/null
    done < ${temp_dir}/cpd-list-crs.out
  fi

  wait_ns_deleted ${NAMESPACE}
}

#
# MAIN CODE
#

if [ -z ${NAMESPACE} ];then command_usage;fi

oc get project ${NAMESPACE} > /dev/null 2>&1
if [ $? -ne 0 ];then
  echo "Namespace ${NAMESPACE} does not exist"
  exit 1
fi

# Ask for final confirmation to delete the namespace
if [ -z "${CPD_CONFIRM_DELETE}" ];then
    read -p "Are you sure you want to delete namespace ${NAMESPACE} (y/N)? " -r
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

# List the CRs in the specified namespace
list_crs ${NAMESPACE}

delete_ns ${NAMESPACE}

exit 0