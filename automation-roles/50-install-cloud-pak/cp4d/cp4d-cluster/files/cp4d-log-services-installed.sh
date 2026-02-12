#!/bin/bash

# Parameters
# $1: Status directory
# $2: OpenShift project for Cloud Pak for Data
# $3: Name of the cartridge to be checked

# The script loops through all cartridges which are being installed and outputs the CR status for each.

# If the CR of a cartridge does not exist, the script fails with exit code 1.
status_dir=$1
project=$2
cartridges=$(cat ${status_dir}/log/${project}-cartridges.json)

exit_code=0

get_logtime() {
  echo $(date "+%Y-%m-%d %H:%M:%S")
}

log() {
  LOG_TIME=$(get_logtime)
  printf "[${LOG_TIME}] ${1}\n" | tee -a ${status_dir}/log/$project-cartridges-state.log
}

log_state() {
  printf "%s: %s\n" "${1}" "${2}" | tee -a ${temp_file}
}

mkdir -p ${status_dir}/state
chmod 777 ${status_dir}/state
temp_file=$(mktemp)

log "----------"
# Check if the connection to the OpenShift cluster is still valid
log "Info: Checking access to project $project"
oc get project $project
if [ $? -ne 0 ];then
  log "Error: Could not access project $project. Has the OpenShift login token expired?"
  exit 99
fi

while true;do
  log "----------"
  log "Checking installation completion of cartridges"
  log "----------"

  # Also write state into temp file
  state_logged=false
  rm -f ${temp_file}
  log_state "service_state" ""
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
    
    cr_cartridge_name=$(echo $cartridges | jq -r --arg cn "$c" '.[] | select(.name == $cn ) | .Component_name')
    cr_cr=$(echo $cartridges | jq -r --arg cn "$c" '.[] | select(.name == $cn ) | .cr_cr')
    cr_name=$(echo $cartridges | jq -r --arg cn "$c" '.[] | select(.name == $cn ) | .cr_name')
    cr_status_attribute=$(echo $cartridges | jq -r --arg cn "$c" '.[] | select(.name == $cn ) | .cr_status_attribute')
    cr_status_completed=$(echo $cartridges | jq -r --arg cn "$c" '.[] | select(.name == $cn ) | .cr_status_completed')

    # Skip undefined cartridges
    if [[ "$cr_cr" == "null" ]] || [[ "$cr_cr" == "" ]];then
      continue
    fi

    # Skip cartridges with undefined status attribute
    if [[ "$cr_status_attribute" == "null" ]] || [[ "$cr_status_attribute" == "" ]];then
      continue
    fi

    state_logged=true

    # Skip cartridge that don't have a CR yet
    oc get --namespace $project $cr_cr $cr_name
    if [ $? -ne 0 ];then
      cr_status="To be installed"
    else
      # Check if status is completed
      cr_status=$(oc get --namespace $project $cr_cr $cr_name -o jsonpath="{.status.$cr_status_attribute}")
    fi
    
    log "Info: Status of $cr_cr object $cr_name is $cr_status"

    # Log the state in the temp file
    log_state "- service" "${cr_cartridge_name}"
    log_state "  state" "${cr_status}"
  done

  # If the state of any cartridge was logged, recorded into the cr-state.out file
  if ${state_logged};then
    cp -r ${temp_file} ${status_dir}/state/cp4d-${project}-cr-state.out
  else
    rm -f ${status_dir}/state/cp4d-${project}-cr-state.out
  fi
  sleep 120
done
exit 0
