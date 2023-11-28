#!/bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

#
# Functions
#
get_logtime() {
  echo $(date "+%Y-%m-%d %H:%M:%S")
}

log() {
  LOG_TIME=$(get_logtime)
  printf "[${LOG_TIME}] ${1}\n" | tee -a ${temp_dir}/$fs_project-olm-fix.log
}

#
# Initialization
#
temp_dir=$(mktemp -d)
sub_file=${temp_dir}/sub.csv
csv_file=${temp_dir}/csv.csv
ip_file=${temp_dir}/ip.csv


#
# Checks
#
# Checking for command jq to exist. This is required to parse the json output to recreate the subscriptions.
if ! command -v jq &> /dev/null;then
  echo "The jq command is required for this script. Please install first."
fi

# Determine the project that runs the operators
oc get project ibm-common-services > /dev/null 2>&1
if [ $? -eq 0 ];then
  fs_project="ibm-common-services"
else
  fs_project=cpd-operators"
fi

#
# Body
#
echo "Temporary directory with logs and output files: ${temp_dir}"

while true;do

  current_ts=$(date +%s)

  log "Collecting OLM information into ${temp_dir}"
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
  log "INFO: Checking all subscriptions in OpenShift project ${fs_project}"
  remediate=false

  cat ${sub_file}
  
  # Check if any subscriptions older than 2 minutes still don't have a CSV
  while IFS=, read -r sub sub_ts csv sub_state;do
    sub_ts_epoch=$(date -d ${sub_ts} +%s)
    if [[ "${csv}" == "" ]] && (( current_ts > (sub_ts_epoch + 120) ));then
      log "WARNING: Subscription ${sub} does not have a valid CSV, will try to remediate." 
      remediate=true
    fi
  done < ${sub_file}

  # Start remediation for all subscriptions
  if ${remediate};then
    cat ${sub_file}
    log "WARNING: Not all operators are correctly installed. All entries should have a CSV and have state AtLatestKnown"
    # Delete all subscriptions that don't have a CSV
    oc get sub -n ${fs_project} -o json | jq 'del(.items[] .metadata.annotations, .items[] .metadata.resourceVersion, .items[] .metadata.creationTimestamp, .items[] .metadata.generation, .items[] .metadata.uid, .items[] .status)' > ${temp_dir}/${fs_project}-subcriptions.json
    while IFS=, read -r sub sub_ts csv sub_state;do
      if [[ "${csv}" == "" ]];then
        log "DIAG: Deleting subscription ${sub}"
        oc delete sub -n ${fs_project} ${sub}
      fi
    done < ${sub_file}
    # Delete orphaned CSVs and their install plans
    while IFS=, read -r csv csv_ts;do
      if ! grep ${csv} ${sub_file};then
        for ip in $(grep ${csv} ${ip_file} | awk '{print $1}');do
          log "REMEDIATE: Deleting install plan $ip, associated with CSV ${csv}"
          oc delete ip -n ${fs_project} $ip --ignore-not-found
        done
        log "REMEDIATE: Deleting orphaned CSV ${csv}"
        oc delete csv -n ${fs_project} ${csv} --ignore-not-found
      fi 
    done < ${csv_file}
    log "REMEDIATE: Re-creating deleted subscriptions"
    oc apply -f ${temp_dir}/${fs_project}-subcriptions.json
    log "END OF REMEDIATION"
  else
    log "INFO: Everything looks good"
  fi

  log "----------"
  log "Finished checking OLM artifacts in project ${fs_project}, sleeping for 60 seconds"
  log "----------"
  sleep 60

done
exit 0