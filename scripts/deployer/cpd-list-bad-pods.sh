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
export ALL_NAMESPACES=false
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
  --all-namespaces*|-A*)
    export ALL_NAMESPACES=true
    shift 1
    ;;
  *) # preserve remaining arguments
    PARAMS="$PARAMS $1"
    shift
    ;;
  esac
done

list_bad_pods() {
  oc get po -n ${NAMESPACE} | \
    grep -v Completed | \
    grep -vE '1/1|2/2|3/3|4/4|5/5|6/6|7/7|8/8|9/9/10/10|11/11'
}

list_bad_pods_all() {
  oc get po -A | \
    grep -v Completed | \
    grep -vE '1/1|2/2|3/3|4/4|5/5|6/6|7/7|8/8|9/9/10/10|11/11'
}

#
# MAIN CODE
#
if [[ "${NAMESPACE}" == "" ]];then
  export NAMESPACE=$(oc project -q)
fi

# Delete the namespace
if ! ${ALL_NAMESPACES};then
  list_bad_pods ${NAMESPACE}
else
  list_bad_pods_all
fi

exit 0