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
  yq eval ".${1} = ${2}" -i ${temp_file}
}

mkdir -p ${status_dir}/state
temp_file=$(mktemp)

while true;do
  rm -f ${temp_file}
  touch ${temp_file}

  completion_perc=0

  deployer_stage=$(cat ${status_dir}/log/cloud-pak-deployer.log | grep -E 'PLAY \[' | tail -1)
  if [[ ! -z ${deployer_stage} ]];then
    log_state "deployer_stage" "\"${deployer_stage}\""
  fi

  last_step=$(cat ${status_dir}/log/cloud-pak-deployer.log | grep -E 'TASK \[' | tail -1)
  if [[ ! -z ${last_step} ]];then
    log_state "last_step" "\"${last_step}\""
  fi

  # Infer the completion percentage from the stage. If at the final stage (80), the percentage should be 100
  if [[ ! -z ${deployer_stage} ]];then
    if [[ $deployer_stage =~ (PLAY \[)([0-9]*) ]];then
      stage_number=${BASH_REMATCH[2]}
      # Before doing the percentage calculation, check that the outcome is numeric
      number_regex='^[0-9]+$'
      if [[ $stage_number =~ $number_regex ]] ; then
        completion_perc=$(( stage_number  * 100 / 80 ))
      else
        completion_perc=0
      fi
    else
      completion_perc=0
    fi
  fi

  # Obtain the Software Hub URL, user and password
  if [ -f ${status_dir}/cloud-paks/cloud-pak-deployer-info.txt ];then
    cp4d_url=$(grep 'CP4D URL:' $STATUS_DIR/cloud-paks/cloud-pak-deployer-info.txt | tail -1 | awk -F'CP4D URL: ' '{print $2}')
    cp4d_user=$(grep 'CP4D User:' $STATUS_DIR/cloud-paks/cloud-pak-deployer-info.txt | tail -1 | awk -F'CP4D User: ' '{print $2}')
    cp4d_password=$(grep CP4D $STATUS_DIR/cloud-paks/cloud-pak-deployer-info.txt | grep password: | awk '{print $NF}')
    if [[ ! -z ${cp4d_url} ]];then
      log_state "cp4d_url" "\"${cp4d_url}\""
    fi
    if [[ ! -z ${cp4d_user} ]];then
      log_state "cp4d_user" "\"${cp4d_user}\""
    fi
    if [[ ! -z ${cp4d_password} ]];then
      log_state "cp4d_password" "\"${cp4d_password}\""
    fi
  fi

  cp4d_state_file=$(ls ${status_dir}/state/cp4d-*-cr-state.out 2>/dev/null | head -n 1)
  if [[ ! -z ${cp4d_state_file} ]];then
    yq eval-all '. as $item ireduce ({}; . * $item)' ${temp_file} ${cp4d_state_file} > ${temp_file}.merged
    mv ${temp_file}.merged ${temp_file}
  fi

  # Log completion state of mirroring images
  if [ -f ${status_dir}/log/cloud-pak-mirror-images.log ];then
    mirror_number_images=0
    mirror_image_number=0
    mirror_number_images_msg=$(cat ${status_dir}/log/cloud-pak-mirror-images.log | grep -E '\[STATE\] Total image count' | tail -1)
    mirror_current_image_msg=$(cat ${status_dir}/log/cloud-pak-mirror-images.log | grep -E '\[STATE\] Current image' | tail -1)
    mirror_image_number_msg=$(cat ${status_dir}/log/cloud-pak-mirror-images.log | grep -E '\[STATE\] Image number' | tail -1)
    if [[ $mirror_number_images_msg =~ ([0-9]+) ]];then
      mirror_number_images=${BASH_REMATCH[1]}
      log_state "mirror_number_images" ${mirror_number_images}
    fi
    if [[ $mirror_image_number_msg =~ ([0-9]+) ]];then
      mirror_image_number=${BASH_REMATCH[1]}
      log_state "mirror_image_number" ${mirror_image_number}
    fi
    if [[ ! -z ${mirror_current_image_msg} ]];then
      mirror_current_image=$(echo ${mirror_current_image_msg} | cut -d: -f2-)
      log_state "mirror_current_image" ${mirror_current_image}
    fi
    if [ ${mirror_number_images} -ne 0 ];then
      completion_perc=$(( mirror_image_number  * 100 / mirror_number_images ))
    fi
  fi

  log_state "percentage_completed" ${completion_perc}

  cp -f ${temp_file} ${status_dir}/state/deployer-state.out
  chmod 777 ${status_dir}/state/deployer-state.out

  sleep 10
done
exit 0