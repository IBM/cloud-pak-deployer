#!/bin/bash
function usage() {
	local script="${0##*/}"

	while read -r ; do echo "${REPLY}" ; done <<-EOF
	Usage: ${script} [OPTION]...
	Uninstall CP4BA project

	Options:
	Mandatory arguments to long options are mandatory for short options too.
	  -h, --help                    display this help and exit
	  -n                            specify the namespace where CP4BA is installed
	EOF
}

function msg() {
  printf '\n%b\n' "$1"
}

function wait_msg() {
  printf '%s\r' "${1}"
}

function success() {
  msg "\33[32m[✔] ${1}\33[0m"
}

function warning() {
  msg "\33[33m[✗] ${1}\33[0m"
}

function error() {
  msg "\33[31m[✘] ${1}\33[0m"
}

function title() {
  msg "\33[1m# [$step] ${1}\33[0m"
  step=$((step + 1))
}

# Sometime delete namespace stuck due to some reousces remaining, use this method to get these
# remaining resources to force delete them.
function get_remaining_resources_from_namespace() {
  local namespace=$1
  local remaining=
  if oc get namespace ${namespace} &>/dev/null; then
    message=$(oc get namespace ${namespace} -o=jsonpath='{.status.conditions[?(@.type=="NamespaceContentRemaining")].message}' | awk -F': ' '{print $2}')
    [[ "X$message" == "X" ]] && return 0
    remaining=$(echo $message | awk '{len=split($0, a, ", ");for(i=1;i<=len;i++)print a[i]" "}' | while read res; do
      [[ "$res" =~ "pod" ]] && continue
      echo ${res} | awk '{print $1}'
    done)
  fi
  echo $remaining
}

# Get remaining resource with kinds
function update_remaining_resources() {
  local remaining=$1
  local ns="--all-namespaces"
  local new_remaining=
  [[ "X$2" != "X" ]] && ns="-n $2"
  for kind in ${remaining}; do
    if [[ "X$(oc get ${kind} --all-namespaces --ignore-not-found)" != "X" ]]; then
      new_remaining="${new_remaining} ${kind}"
    fi
  done
  echo $new_remaining
}

function wait_for_deleted() {
  local remaining=${1}
  retries=${2:-10}
  interval=${3:-30}
  index=0
  while true; do
    remaining=$(update_remaining_resources "$remaining")
    if [[ "X$remaining" != "X" ]]; then
      if [[ ${index} -eq ${retries} ]]; then
        error "Timeout delete resources: $remaining"
        return 1
      fi
      sleep $interval
      ((index++))
      wait_msg "DELETE - Waiting: resource ${remaining} delete complete [$(($retries - $index)) retries left]"
    else
      break
    fi
  done
}

function wait_for_namespace_deleted() {
  local namespace=$1
  retries=25
  interval=10
  index=0
  while true; do
    if oc get namespace ${namespace} &>/dev/null; then
      if [[ ${index} -eq ${retries} ]]; then
        error "Timeout delete namespace: $namespace"
        return 1
      fi
      sleep $interval
      ((index++))
      wait_msg "DELETE - Waiting: namespace ${namespace} delete complete [$(($retries - $index)) retries left]"
    else
      break
    fi
  done
  return 0
}

function delete_operand_finalizer() {
  local crds=$1
  local ns=$2
  for crd in ${crds}; do
    crs=$(oc get ${crd} --no-headers --ignore-not-found -n ${ns} 2>/dev/null | awk '{print $1}')
    for cr in ${crs}; do
      msg "Removing the finalizers for resource: ${crd}/${cr}"
      oc patch ${crd} ${cr} -n ${ns} --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]' 2>/dev/null
    done
  done
}

function delete_unavailable_apiservice() {
  rc=0
  apis=$(oc get apiservice | grep False | awk '{print $1}')
  if [ "X${apis}" != "X" ]; then
    warning "Found some unavailable apiservices, deleting ..."
    for api in ${apis}; do
      msg "oc delete apiservice ${api}"
      oc delete apiservice ${api}
      if [[ "$?" != "0" ]]; then
        error "Delete apiservcie ${api} failed"
        rc=$((rc + 1))
        continue
      fi
    done
  fi
  return $rc
}

function force_delete() {
  local namespace=$1
  local remaining=$(get_remaining_resources_from_namespace "$namespace")
  if [[ "X$remaining" != "X" ]]; then
    warning "Some resources are remaining: $remaining"
    msg "Deleting finalizer for these resources ..."
    delete_operand_finalizer "${remaining}" "$namespace"
    wait_for_deleted "${remaining}" 5 10
  fi
}

#-------------------------------------- Clean UP --------------------------------------#
CP4BA_NS=${CP4BA_NS:-cp4ba}
step=0

while [ "$#" -gt "0" ]
do
	case "$1" in
	"-h"|"--help")
		usage
		exit 0
		;;
	"-n")
		CP4BA_NS=$2
		shift
		;;
	*)
		warning "invalid option -- \`$1\`"
		usage
		exit 1
		;;
	esac
	shift
done

title "Deleting namespace ${CP4BA_NS}"
oc delete namespace ${CP4BA_NS} --ignore-not-found &
if wait_for_namespace_deleted ${CP4BA_NS}; then
  success "CP4BA project uninstall finished and successfull."
  exit 0
fi

title "Force delete remaining resources"
delete_unavailable_apiservice
force_delete "$CP4BA_NS" && success "CP4BA project uninstall finished and successfull." && exit 0
error "Something wrong, woooow ......, check namespace detail:"
oc get namespace ${CP4BA_NS} -oyaml
exit 1
