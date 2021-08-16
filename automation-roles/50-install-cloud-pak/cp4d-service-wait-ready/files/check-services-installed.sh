#!/bin/bash

# Parameters
# $1: OpenShift project for Cloud Pak for Data
# $2: List of cartridges which are being installed
# $3: List of all cartridges with their CR name and status

# The script loops through all cartridges which are being installed and checks the CR status for each.
# The value returned in stdout is the number of cartridges which have not completed installation.
# If the CR of a cartridge does not exist, the script fails with exit code 1.
status_dir=$1
project=$2
cartridges=$(echo $3 | base64 -d)
cartridge_cr=$(echo $4 | base64 -d)

exit_code=0
number_pending=0

get_logtime() {
  echo $(date "+%Y-%m-%d %H:%M:%S")
}

log() {
  LOG_TIME=$(get_logtime)
  printf "[${LOG_TIME}] ${1}\n" | tee -a ${status_dir}/log/$project-cartridges.log
}

log "----"
log "Info: Cartridges to be checked: $(echo $cartridges | jq -r .)"
log "Info: Defined cartridges (cartridge_cr): $(echo $cartridge_cr | jq -r .)"

for c in $(echo $cartridges | jq -r '.[].name');do
  log "Checking cartridge $c" 
  cr_cr=$(echo $cartridge_cr | jq -r --arg cn "$c" '.[] | select(.name == $cn ) | .cr_cr')
  cr_name=$(echo $cartridge_cr | jq -r --arg cn "$c" '.[] | select(.name == $cn ) | .cr_name')
  cr_status_attribute=$(echo $cartridge_cr | jq -r --arg cn "$c" '.[] | select(.name == $cn ) | .cr_status_attribute')
  log "Info: Cartridge: $c, CR: $cr_cr, CR name: $cr_name, CR status attribute: $cr_status_attribute"

  # Check if cartridge has been defined
  if [[ "$cr_cr" == "null" ]] || [[ "$cr_cr" == "" ]];then
    log "Error: Cartridge $c does not have a definition in object cartridges_cr, it seems to be undefined"
    exit_code=2
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
  if [ "$cr_status" != "Completed" ];then
    ((number_pending=number_pending+1))
  fi
done

if [ $exit_code -ne 0 ];then
  exit $exit_code
fi

log "Number of pending cartridge installations: $number_pending"

if [ $number_pending -eq 0 ];then
  log "All cartridges successfully completed"
fi

exit 0
