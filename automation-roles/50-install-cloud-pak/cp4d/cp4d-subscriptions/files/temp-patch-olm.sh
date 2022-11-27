#!/bin/bash

# Parameters
# $1: Status directory
# $2: Foundational Services project

status_dir=$1
fs_project=$2

exit_code=0

get_logtime() {
  echo $(date "+%Y-%m-%d %H:%M:%S")
}

log() {
  LOG_TIME=$(get_logtime)
  printf "[${LOG_TIME}] ${1}\n" | tee -a ${status_dir}/log/$fs_project-patch-olm.log
}

log "----------"
# Check if the connection to the OpenShift cluster is still valid
log "Info: Checking access to project $fs_project"
oc get project $fs_project
if [ $? -ne 0 ];then
  log "ERROR: Could not access project $fs_project. Has the OpenShift login token expired?"
  exit 99
fi

sub_file=$(mktemp)

while true;do
  log "----------"
  log "Checking OLM artifacts in project ${fs_project}"
  log "----------"

  current_ts=$(date +%s)

  oc get sub -n ${fs_project} \
    --sort-by=.metadata.creationTimestamp \
    --no-headers \
    -o jsonpath='{range .items[*]}{.metadata.name}{","}{.metadata.creationTimestamp}{","}{.status.installedCSV}{","}{.status.state}{"\n"}{end}' > ${sub_file}

  while IFS=, read -r sub sub_ts csv sub_state;do
    log "Checking subscription ${sub}: created ${sub_ts}. CSV ${csv}, State ${sub_state}."
    if [[ "${csv}" == "" ]];then
      log "WARNING: Missing CSV for subscription ${sub}, checking age of subscription"
      sub_ts_epoch=$(date -d ${sub_ts} +%s)
      if (( current_ts > (sub_ts_epoch + 120) ));then
        operator_label=$(oc get sub -n ${fs_project} ${sub} -o jsonpath='{.metadata.labels}' | jq -r 'keys[]' | grep "operators.coreos.com")
        log "WARNING: Subscription ${sub} does not have a CSV, remediating..."
        oc get sub -n ${fs_project} ${sub} -o yaml > /tmp/${sub}.yaml
        log "Deleting subscription ${sub}"
        oc delete sub -n ${fs_project} ${sub}
        log "Deleting CSV with label ${operator_label} in case it exists but did not get associated with subscription ${sub}"
        oc delete csv -n ${fs_project} -l ${operator_label}
        log "Recreating subscription ${sub}"
        oc apply -f /tmp/${sub}.yaml
        # Break the current while loop, only recreate one subscription at a time
        break
      else
        log "Subscription ${sub} will not (yet) be recreated"
      fi
    fi
  done < ${sub_file}

  log "----------"
  log "Finished checking OLM artifacts in project ${fs_project}"
  log "----------"
  sleep 60

done
exit 0
