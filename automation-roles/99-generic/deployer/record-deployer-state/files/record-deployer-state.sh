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
  printf "%s: %s\n" "${1}" "${2}" | tee -a ${temp_file}
}

mkdir -p ${status_dir}/state
temp_file=$(mktemp)

while true;do
  rm -f ${temp_file}

  deployer_stage=$(cat ${status_dir}/log/cloud-pak-deployer.log | grep -E 'PLAY \[' | tail -1)
  log_state "deployer_stage" "\"${deployer_stage}\""

  last_step=$(cat ${status_dir}/log/cloud-pak-deployer.log | grep -E 'TASK \[' | tail -1)
  log_state "last_step" "\"${last_step}\""

  if [[ $current_stage =~ (PLAY \[)([0-9]*) ]];then
    completion_perc=${BASH_REMATCH[2]}
  else
    completion_perc=00
  fi
  log_state "percentage_completed" ${completion_perc}

  # Write service state (placeholder for now)
  log_state "service_state" ""
  log_state "- service" "cpd_platform"
  log_state "  state" "Completed"
  log_state "- service" "wml"
  log_state "  state" "Catalog Source created"
  log_state "- service" "wkc"
  log_state "  state" "Operator installed"
  log_state "- service" "ws"
  log_state "  state" "In progress"

  mv -f ${temp_file} ${status_dir}/state/deployer-state.out

  sleep 60
done
exit 0
