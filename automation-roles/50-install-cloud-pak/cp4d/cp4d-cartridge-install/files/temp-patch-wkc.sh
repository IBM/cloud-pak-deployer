#!/bin/bash

# Parameters
# $1: Status directory
# $2: OpenShift project for Cloud Pak for Data

status_dir=$1
project=$2

exit_code=0

get_logtime() {
  echo $(date "+%Y-%m-%d %H:%M:%S")
}

log() {
  LOG_TIME=$(get_logtime)
  printf "[${LOG_TIME}] ${1}\n" | tee -a ${status_dir}/log/$project-wkc-temp-patch.log
}

log "----------"
# Check if the connection to the OpenShift cluster is still valid
log "Info: Checking access to project $project"
oc get project $project
if [ $? -ne 0 ];then
  log "Error: Could not access project $project. Has the OpenShift login token expired?"
  exit 99
fi

while true;do
  log "----------"
  log "Checking Db2u statefulsets"
  log "----------"

  for db2ucluster in $(oc get -n $project db2ucluster --no-headers | awk '{print $1}');do
    log "Found db2ucluster: $db2ucluster"
    sts_name="c-${db2ucluster}-db2u"
    pod_name="${sts_name}-0"
    # Check if the ping error occurred
    if oc logs -n $project ${pod_name} | grep -q "ping: socket: Operation not permitted";then
      log "Found pod with ping error: ${pod_name}"
      # Pause the probe if the db2ucluster deployment is restricted
      if oc get db2ucluster -n $project ${db2ucluster} -o yaml | grep -q -i "restricted: true";then
        oc exec -ti -n $project ${pod_name} -- /bin/bash -c "touch /db2u/tmp/.pause_probe"
      fi
      # Patch sysctl in statefulset
      if oc get sts -n $project ${sts_name} -o yaml | grep -q "sysctls";then
        log "Patching sysctls when sysctls exists in statetefulset ${sts_name}"
        oc patch sts -n $project ${sts_name} --type json -p '[{"op":"add","path":"/spec/template/spec/securityContext/sysctls/-","value":{"name":"net.ipv4.ping_group_range","value":"0 2147483647"}}]'
      else
        log "Adding sysctls when sysctls does not exists in statetefulset ${sts_name}"
        oc patch sts -n $project ${sts_name} -p '{"spec": {"template":{"spec":{"securityContext":{"sysctls":[{"name": "net.ipv4.ping_group_range","value": "0 2147483647"}]}}}}}'
      fi
      # Resume the probe if the db2ucluster deployment is restricted
      if oc get db2ucluster -n $project ${db2ucluster} -o yaml | grep -q -i "restricted: true";then
        oc exec -ti -n $project ${pod_name} -- /bin/bash -c "rm -f /db2u/tmp/.pause_probe"
      fi
    fi
  done
  log "----------"
  log "Finished checks"
  sleep 600
done
exit 0
