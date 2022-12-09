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

  cp4d_state_file=$(ls ${status_dir}/state/cp4d-*-cr-state.out 2>/dev/null | head -n 1)
  if [[ ! -z ${cp4d_state_file} ]];then
    cat ${cp4d_state_file} >> ${temp_file}
  fi

  mv -f ${temp_file} ${status_dir}/state/deployer-state.out

  sleep 60
done
exit 0
