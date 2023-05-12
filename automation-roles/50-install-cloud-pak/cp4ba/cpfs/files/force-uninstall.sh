#!/bin/bash
#
# Copyright 2021 IBM Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http:#www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

function usage() {
	local script="${0##*/}"

	while read -r ; do echo "${REPLY}" ; done <<-EOF
	Usage: ${script} [OPTION]...
	Uninstall common services

	Options:
	Mandatory arguments to long options are mandatory for short options too.
	  -h, --help                    display this help and exit
	  -n                            specify the namespace where common service is installed
	  -f                            force delete specified or default ibm-common-services namespace, skip normal uninstall steps
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
  retries=15
  interval=5
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

function delete_operator() {
  local subs=$1
  local namespace=$2
  for sub in ${subs}; do
    csv=$(oc get sub ${sub} -n ${namespace} -o=jsonpath='{.status.installedCSV}' --ignore-not-found)
    if [[ "X${csv}" != "X" ]]; then
      msg "Delete operator ${sub} from namespace ${namespace}"
      oc delete csv ${csv} -n ${namespace} --ignore-not-found
      oc delete sub ${sub} -n ${namespace} --ignore-not-found
    fi
  done
}

function delete_operand() {
  local crds=$1
  for crd in ${crds}; do
    if oc api-resources | grep $crd &>/dev/null; then
      for ns in $(oc get $crd --no-headers --all-namespaces --ignore-not-found | awk '{print $1}' | sort -n | uniq); do
        crs=$(oc get ${crd} --no-headers --ignore-not-found -n ${ns} 2>/dev/null | awk '{print $1}')
        if [[ "X${crs}" != "X" ]]; then
          msg "Deleting ${crd} from namespace ${ns}"
          oc delete ${crd} --all -n ${ns} --ignore-not-found &
        fi
      done
    fi
  done
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

function delete_rbac_resource() {
  oc delete ClusterRoleBinding ibm-common-service-webhook secretshare-${COMMON_SERVICES_NS} $(oc get ClusterRoleBinding | grep nginx-ingress-clusterrole | awk '{print $1}') --ignore-not-found
  oc delete ClusterRole ibm-common-service-webhook secretshare nginx-ingress-clusterrole --ignore-not-found
  oc delete RoleBinding ibmcloud-cluster-info ibmcloud-cluster-ca-cert -n kube-public --ignore-not-found
  oc delete Role ibmcloud-cluster-info ibmcloud-cluster-ca-cert -n kube-public --ignore-not-found
  oc delete scc nginx-ingress-scc --ignore-not-found
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
COMMON_SERVICES_NS=${COMMON_SERVICES_NS:-ibm-common-services}
step=0
FORCE_DELETE=false

while [ "$#" -gt "0" ]
do
	case "$1" in
	"-h"|"--help")
		usage
		exit 0
		;;
	"-f")
		FORCE_DELETE=true
		;;
	"-n")
		COMMON_SERVICES_NS=$2
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

if [[ "$FORCE_DELETE" == "false" ]]; then
  # Before uninstall common services, we should delete some unavailable apiservice
  delete_unavailable_apiservice

  title "Deleting ibm-common-service-operator"
  for sub in $(oc get sub --all-namespaces --ignore-not-found | awk '{if ($3 =="ibm-common-service-operator") print $1"/"$2}'); do
    namespace=$(echo $sub | awk -F'/' '{print $1}')
    name=$(echo $sub | awk -F'/' '{print $2}')
    delete_operator "$name" "$namespace"
  done

  title "Deleting common services operand from all namespaces"
  delete_operand "OperandRequest" && wait_for_deleted "OperandRequest" 30 20
  delete_operand "CommonService OperandRegistry OperandConfig"
  delete_operand "NamespaceScope" && wait_for_deleted "NamespaceScope"

  # Delete the previous version ODLM operator
  if oc get sub operand-deployment-lifecycle-manager-app -n openshift-operators &>/dev/null; then
    title "Deleting ODLM Operator"
    delete_operator "operand-deployment-lifecycle-manager-app" "openshift-operators"
  fi

  title "Deleting RBAC resources"
  delete_rbac_resource

  title "Deleting webhooks"
  oc delete ValidatingWebhookConfiguration cert-manager-webhook ibm-cs-ns-mapping-webhook-configuration --ignore-not-found
  oc delete MutatingWebhookConfiguration cert-manager-webhook ibm-common-service-webhook-configuration ibm-operandrequest-webhook-configuration namespace-admission-config --ignore-not-found
fi

title "Deleting iam-status configMap in kube-public namespace"
oc delete configmap ibm-common-services-status -n kube-public --ignore-not-found

title "Deleting namespace ${COMMON_SERVICES_NS}"
oc delete namespace ${COMMON_SERVICES_NS} --ignore-not-found &
if wait_for_namespace_deleted ${COMMON_SERVICES_NS}; then
  success "Common Services uninstall finished and successfull."
  exit 0
fi

title "Force delete remaining resources"
delete_unavailable_apiservice
force_delete "$COMMON_SERVICES_NS" && success "Common Services uninstall finished and successfull." && exit 0
error "Something wrong, woooow ......, check namespace detail:"
oc get namespace ${COMMON_SERVICES_NS} -oyaml
exit 1
