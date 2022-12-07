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

mkdir -p ${status_dir}/state
temp_file=$(mktemp)

while true;do
  rm -f ${temp_file}

  current_stage=$(cat ${status_dir}/log/cloud-pak-deployer.log | grep -E 'PLAY \[' | tail -1)
  log_state "current_stage" "\"${current_stage}\""

  last_step=$(cat ${status_dir}/log/cloud-pak-deployer.log | grep -E 'TASK \[' | tail -1)
  log_state "last_step" "\"${last_step}\""

  if [[ $current_stage =~ (PLAY \[)([0-9]*) ]];then
    completion_perc=${BASH_REMATCH[2]}
  else
    completion_perc=00
  fi
  log_state "percentage_completed" ${completion_perc}

  # Write service state (placeholder for now)
  printf "service_state:\n" | tee -a ${temp_file}
  printf "- service: cpd_platform\n" | tee -a ${temp_file}
  printf "  state: Completed\n" | tee -a ${temp_file}
  printf "- service: wml\n" | tee -a ${temp_file}
  printf "  state: Catalog Source created\n" | tee -a ${temp_file}
  printf "- service: wkc\n" | tee -a ${temp_file}
  printf "  state: Operator installed\n" | tee -a ${temp_file}
  printf "- service: ws\n" | tee -a ${temp_file}
  printf "  state: In progress\n" | tee -a ${temp_file}

  mv -f ${temp_file} ${status_dir}/state/deployer-state.out

  sleep 60
done
exit 0
