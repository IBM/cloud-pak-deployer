#!/bin/bash

# Parameters
# $1: Status directory

status_dir=$1

exit_code=0

get_logtime() {
  echo $(date "+%Y-%m-%d %H:%M:%S")
}

log() {
  LOG_TIME=$(get_logtime)
  printf "[${LOG_TIME}] ${1}\n" | tee -a ${status_dir}/log/record-deployer-state.log
}

log_state() {
  printf "${1}: ${2}\n" | tee -a ${temp_file}
}

temp_file=$(mktemp)

log "----------"
# Check if the connection to the OpenShift cluster is still valid
# log "Info: Checking access to project default"
# oc get project default
# if [ $? -ne 0 ];then
#   log "Error: Could not access project default. Has the OpenShift login token expired?"
#   exit 99
# fi

while true;do
  log "----------"
  log "Checking state of the deployer process"
  log "----------"

  rm -f ${temp_file}

  current_stage=$(cat ${status_dir}/log/cloud-pak-deployer.log | grep -E 'PLAY \[' | tail -1)
  log_state "current-stage" "\"${current_stage}\""

  current_task=$(cat ${status_dir}/log/cloud-pak-deployer.log | grep -E 'TASK \[' | tail -1)
  log_state "current-task" "\"${current_task}\""

  log_state "deployer-status" "ACTIVE"

  mv -f ${temp_file} ${status_dir}/log/deployer-state.out

  log "----------"
  log "Finished checks, sleeping for 1 minute"
  sleep 60
done
exit 0
