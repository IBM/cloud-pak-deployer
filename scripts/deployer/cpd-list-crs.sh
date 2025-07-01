#!/bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )


command_usage() {
  echo
  echo "Usage: $0 [-n <NAMESPACE>] [--no-headers]"
  exit $1
}

#
# PARSE
#
# Parse parameters
NO_HEADERS=false
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
    ;;
  --no-headers)
    export NO_HEADERS=true
    shift 1
    ;;
  *) # preserve remaining arguments
    PARAMS="$PARAMS $1"
    shift
    ;;
  esac
done

list_crs() {
  NAMESPACE=$1
  oc get project ${NAMESPACE} > /dev/null 2>&1
  if [ $? -eq 0 ];then
    echo Listing custom resources in namespace ${NAMESPACE} ... >&2
    tempfile=$(mktemp)
    if [ "${NO_HEADERS}" != "true" ];then
      echo "KIND NAME" > ${tempfile}
    fi
    oc get --no-headers -n ${NAMESPACE} $(oc get crd -o=custom-columns=CR_NAME:.metadata.name,SCOPE:.spec.scope | \
        grep -i namespaced | awk '{printf "%s%s",sep,$1;sep=","}') \
        --ignore-not-found 2>/dev/null | awk '{split($1,a,"/");printf "%s %s\n",a[1],a[2]}' >> ${tempfile}
    cat ${tempfile} | column -t
  else
    echo "Namespace ${NAMESPACE} does not exist" >&2
    exit 1
  fi
}

#
# MAIN CODE
#
if [[ "${NAMESPACE}" == "" ]];then
  export NAMESPACE=$(oc project -q)
fi

# List the CRs in the specified namespace
list_crs ${NAMESPACE}

exit 0