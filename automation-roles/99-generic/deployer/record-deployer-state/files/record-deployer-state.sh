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

while true;do
  rm -f ${temp_file}

  current_stage=$(cat ${status_dir}/log/cloud-pak-deployer.log | grep -E 'PLAY \[' | tail -1)
  log_state "current-stage" "\"${current_stage}\""

  current_task=$(cat ${status_dir}/log/cloud-pak-deployer.log | grep -E 'TASK \[' | tail -1)
  log_state "current-task" "\"${current_task}\""

  if [[ $current_stage =~ (PLAY \[)([0-9]*) ]];then
    completion_perc=${BASH_REMATCH[2]}
  else
    completion_perc=00
  fi
  log_state "completed-percentage" ${completion_perc}

  mv -f ${temp_file} ${status_dir}/log/deployer-state.out

  sleep 60
done
exit 0
