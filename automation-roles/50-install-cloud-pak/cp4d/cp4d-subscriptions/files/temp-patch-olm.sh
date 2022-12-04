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
csv_file=$(mktemp)
ip_file=$(mktemp)

while true;do
  log "----------"
  log "Checking OLM artifacts in project ${fs_project}"
  log "----------"

  current_ts=$(date +%s)

  oc get sub -n ${fs_project} \
    --sort-by=.metadata.creationTimestamp \
    --no-headers \
    -o jsonpath='{range .items[*]}{.metadata.name}{","}{.metadata.creationTimestamp}{","}{.status.installedCSV}{","}{.status.state}{"\n"}{end}' > ${sub_file}

  oc get csv -n ${fs_project} \
    --sort-by=.metadata.creationTimestamp \
    --no-headers \
    -o jsonpath='{range .items[*]}{.metadata.name}{","}{.metadata.creationTimestamp}{"\n"}{end}' > ${csv_file}

  oc get ip -n ${fs_project} \
    --no-headers \
    -o jsonpath='{range .items[*]}{.metadata.name} {.spec.clusterServiceVersionNames}{"\n"}{end}' > ${ip_file}

  # Check if there are any subscriptions that don't have a CSV associated
  diag_dir=""
  while IFS=, read -r sub sub_ts csv sub_state;do
    log "Checking subscription ${sub}: created ${sub_ts}. CSV ${csv}, State ${sub_state}."
    sub_ts_epoch=$(date -d ${sub_ts} +%s)
    if [[ "${csv}" == "" ]] && (( current_ts > (sub_ts_epoch + 300) ));then
      if [[ "${diag_dir}" == "" ]];then
        diag_dir=${status_dir}/log/olm-diag-${current_ts}
      fi
      log "WARNING: Subscription ${sub} does not have a valid CSV, remediating. Diagnostics info in ${diag_dir}" 
    fi
  done < ${sub_file}

  # Start remediation for all subscriptions
  if [[ "${diag_dir}" != "" ]];then
    log "WARNING: Remediating invalid subscriptions ${diag_dir}"
    # Create diag dir and copy files into t
    mkdir -p ${diag_dir}
    cp ${sub_file} ${diag_dir}/sub-diag.csv
    cp ${csv_file} ${diag_dir}/csv-diag.csv
    cp ${ip_file} ${diag_dir}/ip-diag.csv
    log "DIAG: Collecting OLM operator logs to ${diag_dir}"
    oc logs -n openshift-operator-lifecycle-manager -l app=catalog-operator \
      --timestamps > ${diag_dir}/catalog-operator.log
    oc logs -n openshift-operator-lifecycle-manager -l app=olm-operator \
      --timestamps > ${diag_dir}/olm-operator.log
    # Delete all subscriptions that don't have a CSV
    while IFS=, read -r sub sub_ts csv sub_state;do
      if [[ "${csv}" == "" ]];then
        log "WARNING: Exporting subscription ${sub} to ${diag_dir}/sub-${sub}.yaml and deleting"
        oc get sub -n ${fs_project} ${sub} -o yaml > ${diag_dir}/sub-${sub}.yaml
        oc delete sub -n ${fs_project} ${sub}
      fi
    done < ${diag_dir}/sub-diag.csv
    # Delete orphaned CSVs and their install plans
    while IFS=, read -r csv csv_ts;do
      if ! grep ${csv} ${sub_file};then
        log "WARNING: Orphaned CSV ${csv} found, exporting to ${diag_dir}/csv-${csv}.yaml"
        oc get csv -n ${fs_project} ${csv} -o yaml > ${diag_dir}/csv-${csv}.yaml
        for ip in $(grep ${csv} ${diag_dir}/ip-diag.csv | awk '{print $1}');do
          log "Deleting install plan $ip, associated with CSV ${csv}"
          oc delete ip -n ${fs_project} $ip --ignore-not-found
        done
        log "Deleting orphaned CSV ${csv}"
        oc delete csv -n ${fs_project} ${csv} --ignore-not-found
      fi 
    done < ${diag_dir}/csv-diag.csv
    # Recreating all deleted subscriptions
    while IFS=, read -r sub sub_ts csv sub_state;do
      if [[ "${csv}" == "" ]];then
        log "Recreating subscription ${sub} from ${diag_dir}/sub-${sub}.yaml"
        oc apply -f ${diag_dir}/sub-${sub}.yaml
        log "Sleeping for 60 seconds"
        sleep 60
      fi
    done < ${diag_dir}/sub-diag.csv
    log "WARNING: END OF REMEDIATION"
  fi

  log "----------"
  log "Finished checking OLM artifacts in project ${fs_project}"
  log "----------"
  sleep 60

done
exit 0