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
      # If the subscription is more than 5 minutes old and still no CSV assigned, recreate it
      if (( current_ts > (sub_ts_epoch + 300) ));then
        diag_dir=$(mktemp -d -p ${status_dir}/log)
        operator_label=$(oc get sub -n ${fs_project} ${sub} -o jsonpath='{.metadata.labels}' | jq -r 'keys[]' | grep "operators.coreos.com")
        log "WARNING: Subscription ${sub} does not have a CSV, remediating. Diagnostics info in ${diag_dir}"
        log "DIAG: Retrieving subscription definition ${sub} to ${diag_dir}/${sub}.yaml"
        oc get sub -n ${fs_project} ${sub} -o yaml > ${diag_dir}/${sub}.yaml
        log "DIAG: Retrieving CSV definition to ${diag_dir}/${sub}-csv.yaml"
        oc get csv -n ${fs_project} -l ${operator_label} -o yaml > ${diag_dir}/${sub}-csv.yaml
        log "DIAG: Retrieving install plans to ${diag_dir}/install-plans.yaml"
        oc get ip -n ${fs_project} -o yaml > ${diag_dir}/install-plans.yaml
        log "DIAG: Collecting OLM operator logs to ${diag_dir}"
        oc logs -n openshift-operator-lifecycle-manager -l app=catalog-operator --timestamps > ${diag_dir}/catalog-operator.log
        oc logs -n openshift-operator-lifecycle-manager -l app=olm-operator --timestamps > ${diag_dir}/olm-operator.log
        # log "Deleting subscription ${sub}"
        # oc delete sub -n ${fs_project} ${sub}
        for csv in $(oc get csv -n ${fs_project} -l ${operator_label} -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}');do
          for ip in $(oc get ip -n ${fs_project} --no-headers | grep ${csv} | awk '{print $1}');do
            log "Deleting install plan $ip, associated with CSV ${csv}"
            oc delete ip -n ${fs_project} $ip
          done
          log "Deleting CSV ${csv} which is not associated with subscription ${sub}"
          oc delete csv -n ${fs_project} ${csv}
        done
        # log "Recreating subscription ${sub}"
        # oc apply -f ${diag_dir}/${sub}.yaml
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
