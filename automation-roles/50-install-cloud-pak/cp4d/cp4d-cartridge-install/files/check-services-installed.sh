#!/bin/bash

# Parameters
# $1: Status directory
# $2: OpenShift project for Cloud Pak for Data
# $3: Name of the cartridge to be checked

# The script loops through all cartridges which are being installed and checks the CR status for each.
# It also checks the installation state of the current cartridge. If installation of the current cartridge
# is complete, the calling playbook can continue with the checking of the next cartridge.

# If the CR of a cartridge does not exist, the script fails with exit code 1.
status_dir=$1
project=$2
cartridges=$(cat ${status_dir}/log/${project}-cartridges.json)
current_cartridge_name=$3

exit_code=0
number_pending=0
current_cartridge_installed=false

get_logtime() {
  echo $(date "+%Y-%m-%d %H:%M:%S")
}

log() {
  LOG_TIME=$(get_logtime)
  printf "[${LOG_TIME}] ${1}\n" | tee -a ${status_dir}/log/$project-cartridges.log
}

log "----------"
# Check if the connection to the OpenShift cluster is still valid
log "Info: Checking access to project $project"
oc get project $project
if [ $? -ne 0 ];then
  log "Error: Could not access project $project"
  exit 99
fi

# First-time processing only
if [ ! -f /tmp/check-services-installed.id ];then
  log "Info: Defined cartridges and attributes: $(echo $cartridges | jq -r .)"
  for c in $(echo $cartridges | jq -r '.[].name');do
    # Check state of cartridge
    cartridge_state=$(echo $cartridges | jq -r --arg cn "$c" '.[] | select(.name == $cn ) | .state')
    log "Cartridge $c state: $cartridge_state"
    if [[ "$cartridge_state" == "removed" ]];then
      log "Cartridge $c has been defined as removed"
      continue
    fi
    cr_cr=$(echo $cartridges | jq -r --arg cn "$c" '.[] | select(.name == $cn ) | .cr_cr')
    cr_status_attribute=$(echo $cartridges | jq -r --arg cn "$c" '.[] | select(.name == $cn ) | .cr_status_attribute')
    # Check if cartridge has been defined
    if [[ "$cr_cr" == "null" ]] || [[ "$cr_cr" == "" ]];then
      log "Warning: Cartridge $c does not have a definition in object cartridges_cr, it will not be waited for."
      continue
    fi
    if [[ "$cr_status_attribute" == "null" ]] || [[ "$cr_status_attribute" == "" ]];then
      log "Warning: Cartridge $c does not have a completion status attribute in cartridges_cr, it will not be waited for."
      continue
    fi
  done
  touch /tmp/check-services-installed.id
fi

log "Checking installation completion of cartridge ${current_cartridge_name}"
for c in $(echo $cartridges | jq -r '.[].name');do
  # Check state of cartridge
  cartridge_state=$(echo $cartridges | jq -r --arg cn "$c" '.[] | select(.name == $cn ) | .state')
  if [[ "$cartridge_state" == "removed" ]];then
    continue
  fi

  cartridge_internal=$(echo $cartridges | jq -r --arg cn "$c" '.[] | select(.name == $cn ) | .cr_internal // false')
  if [[ "$cartridge_internal" == "true" ]];then
    continue
  fi  
  
  cr_cartridge_name=$(echo $cartridges | jq -r --arg cn "$c" '.[] | select(.name == $cn ) | .name')
  cr_cr=$(echo $cartridges | jq -r --arg cn "$c" '.[] | select(.name == $cn ) | .cr_cr')
  cr_name=$(echo $cartridges | jq -r --arg cn "$c" '.[] | select(.name == $cn ) | .cr_name')
  cr_status_attribute=$(echo $cartridges | jq -r --arg cn "$c" '.[] | select(.name == $cn ) | .cr_status_attribute')
  cr_status_completed=$(echo $cartridges | jq -r --arg cn "$c" '.[] | select(.name == $cn ) | .cr_status_completed')
  cr_operator_label=$(echo $cartridges | jq -r --arg cn "$c" '.[] | select(.name == $cn ) | .cr_operator_label')

  # Check if current cartridge has been defined
  if [[ "$cr_cr" == "null" ]] || [[ "$cr_cr" == "" ]];then
    if [[ "$c" == "$current_cartridge_name" ]];then
      current_cartridge_installed=true
    fi
    continue
  fi

  # Check if cartridge status attribute has been defined
  if [[ "$cr_status_attribute" == "null" ]] || [[ "$cr_status_attribute" == "" ]];then
    if [[ "$c" == "$current_cartridge_name" ]];then
      current_cartridge_installed=true
    fi
    continue
  fi

  # Check if object exists
  oc get --namespace $project $cr_cr $cr_name
  if [ $? -ne 0 ];then
    log "Error: $cr_cr object $cr_name does not exist in project $project"
    exit_code=3
    continue
  fi

  # TODO: Remove the patching of Db2 statefulsets once tty issue has been resolved
  # If cartridge is wkc, check patch Db2 statefulsets
  if [ "$c" == "wkc" ];then
    log "Info: Check if we need to patch the Db2 StatefulSets for WKC"
    oc patch statefulset --namespace $project c-db2oltp-wkc-db2u \
      -p='{"spec":{"template":{"spec":{"containers":[{"name":"db2u","tty":false}]}}}}}'
    oc patch statefulset --namespace $project c-db2oltp-iis-db2u \
      -p='{"spec":{"template":{"spec":{"containers":[{"name":"db2u","tty":false}]}}}}}'
  fi

  # Check if status is completed
  cr_status=$(oc get --namespace $project $cr_cr $cr_name -o jsonpath="{.status.$cr_status_attribute}")
  log "Info: Status of $cr_cr object $cr_name is $cr_status"
  if [ "$cr_status" != "$cr_status_completed" ];then
    ((number_pending=number_pending+1))
    # If the CR installation has failed, extract the logs
    if [[ "$cr_operator_label" != "" ]] && [[ "${cr_status,,}" == "fail"* ]];then
      oc get po -n $project > $status_dir/log/$project-$c-pods.log
      oc logs -n ibm-common-services -l app.kubernetes.io/name=$cr_operator_label > $status_dir/log/$project-$c-operator.log
    fi
  else
    # If current cartridge is completed, return completion status
    if [[ "$c" == "$current_cartridge_name" ]];then
      current_cartridge_installed=true
    fi
  fi
done

if [ $exit_code -ne 0 ];then
  exit $exit_code
fi

log "Number of pending cartridge installations: $number_pending"

if $current_cartridge_installed;then
  log "${current_cartridge_name} cartridge installation successfully completed"
fi

exit 0
