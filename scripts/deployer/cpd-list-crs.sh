#!/bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )


command_usage() {
  echo
  echo "Usage: $0 [-n <NAMESPACE>]"
  exit $1
}

#
# PARSE
#
# Parse parameters
PARAMS=""
while (( "$#" )); do
  echo $1
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
      echo "Error: Missing cnamespace for --namespace parameter."
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

list_crs() {
  tempfile=$(mktemp)
  echo "KIND NAME" > ${tempfile}
  oc get --no-headers -n $NAMESPACE $(oc get crd -o=custom-columns=CR_NAME:.metadata.name,SCOPE:.spec.scope | \
      grep -i namespaced | awk '{printf "%s%s",sep,$1;sep=","}') \
      --ignore-not-found 2>/dev/null | awk '{split($1,a,"/");printf "%s %s\n",a[1],a[2]}' >> ${tempfile}
  cat ${tempfile} | column -t
}

#
# MAIN CODE
#
if [[ "${NAMESPACE}" == "" ]];then
  export NAMESPACE=$(oc project -q)
fi

# Delete the namespace
list_crs ${NAMESPACE}

exit 0