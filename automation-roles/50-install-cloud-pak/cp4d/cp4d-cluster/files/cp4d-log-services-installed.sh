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

mkdir -p ${status_dir}/state
chmod 777 ${status_dir}/state
temp_file=$(mktemp)
temp_json_file=$(mktemp)

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

  log "Running get-cr-status"
  get-cr-status --cpd_instance_ns=${project}
  cat /tmp/work/status.csv | yq -p csv -o json > ${temp_json_file}

  # Also write state into temp file
  state_logged=false
  rm -f ${temp_file}
  touch ${temp_file}

  for c in $(echo $cartridges | jq -r '.[].olm_utils_name');do
    # Check state of cartridge
    cartridge_state=$(echo $cartridges | jq -r --arg cn "$c" '.[] | select(.olm_utils_name == $cn ) | .state')
    if [[ "$cartridge_state" == "removed" ]];then
      continue
    fi

    cartridge_internal=$(echo $cartridges | jq -r --arg cn "$c" '.[] | select(.olm_utils_name == $cn ) | .cr_internal // false')
    if [[ "$cartridge_internal" == "true" ]];then
      continue
    fi  
    
    cr_cartridge_name=$(echo $cartridges | jq -r --arg cn "$c" '.[] | select(.olm_utils_name == $cn ) | .Component_name')
    cr_cr=$(echo $cartridges | jq -r --arg cn "$c" '.[] | select(.olm_utils_name == $cn ) | .cr_cr')
    cr_name=$(echo $cartridges | jq -r --arg cn "$c" '.[] | select(.olm_utils_name == $cn ) | .cr_name')
    cr_status_attribute=$(echo $cartridges | jq -r --arg cn "$c" '.[] | select(.olm_utils_name == $cn ) | .cr_status_attribute')
    cr_status_completed=$(echo $cartridges | jq -r --arg cn "$c" '.[] | select(.olm_utils_name == $cn ) | .cr_status_completed')
    cr_version=$(echo $cartridges | jq -r --arg cn "$c" '.[] | select(.olm_utils_name == $cn ) | .CR_Version')
    cr_status=$(jq -r --arg cn "$c" '.[] | select(.Components == $cn) | .Status' ${temp_json_file})
    cr_progress=$(jq -r --arg cn "$c" '.[] | select(.Components == $cn) | .Progress' ${temp_json_file})

    # Skip undefined cartridges
    if [[ "$cr_cr" == "null" ]] || [[ "$cr_cr" == "" ]];then
      continue
    fi

    state_logged=true

    log "Info: Status of $cr_cr object $cr_name is $cr_status"

    if [[ -z ${cr_status} ]];then cr_status="To be installed";fi

    # Merge the service state with the other services
    yq -i '.service_state += [{"service":"'$c'","state":"'$cr_status'","progress":"'$cr_progress'","version":"'$cr_version'"}]' ${temp_file}

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
