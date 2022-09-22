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
  printf "[${LOG_TIME}] ${1}\n" | tee -a ${status_dir}/log/$project-db2u-temp-patch.log
}

log "----------"
# Check if the connection to the OpenShift cluster is still valid
log "Info: Checking access to project $project"
oc get project $project
if [ $? -ne 0 ];then
  log "Error: Could not access project $project. Has the OpenShift login token expired?"
  exit 99
fi

# Check if db2ucluster crd exists
if ! oc get crd db2uclusters.db2u.databases.ibm.com;then
  log "Info: No Db2UCluster Custom Resource Definition found, exiting"
  exit 0
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
        log "Pausing probe in pod ${pod_name}"
        oc exec -ti -n $project ${pod_name} -- /bin/bash -c "touch /db2u/tmp/.pause_probe"
        # Now wait for pod to become ready
        log "Waiting for pod ${pod_name} to become ready"
        container_ready="false"
        waittime=0
        while [ "${container_ready}" != "true" ] && [ $waittime -lt 300 ]; do
          sleep 5
          container_ready=$(oc get pod ${pod_name} -o=json | jq -r '.status.containerStatuses[0].ready')
          log "Container of pod ${pod_name} ready: ${container_ready}"
          waittime=$((waittime+5))
        done
        if [ $waittime -ge 300 ];then
          echo "ERROR: Timeout while waiting for pod ${pod_name} to become ready"
        fi
        # Now wait for formation to converge
        log "Waiting for formation ${db2ucluster} to converge"
        formation_converged="false"
        waittime=0
        while [ "${formation_converged}" != "OK" ] && [ $waittime -lt 300 ]; do
          sleep 5
          formation_converged=$(oc get formation ${db2ucluster} -o=json | jq -r '.status.components[] | select(.kind=="StatefulSet") | .status.state')
          log "Convergence state of formation ${db2ucluster} ready: ${formation_converged}"
          waittime=$((waittime+5))
        done
        if [ $waittime -ge 300 ];then
          echo "ERROR: Timeout while waiting for formation ${db2ucluster} to converge"
        fi
      fi
      # Patch sysctl in statefulset
      if oc get sts -n $project ${sts_name} -o yaml | grep -q "sysctls";then
        if ! oc get sts -n $project ${sts_name} -o yaml | grep -q "net.ipv4.ping_group_range";then
          log "Adding sysctls when sysctls exists in statetefulset ${sts_name}"
          oc patch sts -n $project ${sts_name} --type json -p '[{"op":"add","path":"/spec/template/spec/securityContext/sysctls/-","value":{"name":"net.ipv4.ping_group_range","value":"0 2147483647"}}]'
        else
          log "Patch for net.ipv4.ping_group_range already in place, skipped"
        fi
      else
        log "Patching sysctls when sysctls does not exist in statetefulset ${sts_name}"
        oc patch sts -n $project ${sts_name} -p '{"spec": {"template":{"spec":{"securityContext":{"sysctls":[{"name": "net.ipv4.ping_group_range","value": "0 2147483647"}]}}}}}'
      fi
    fi

    # Check if the configmap must be patched
    if oc extract -n ${project} cm/db2aaservice-databases-watch-cm --to=- | grep addDatabaseTriggered;then
      temp_dir=$(mktemp -d)
      echo "Patching ConfigMap db2aaservice-databases-watch-cm to remove addDatabaseTriggered attribute."
      oc extract -n ${project} cm/db2aaservice-databases-watch-cm --to=${temp_dir}
      cat ${temp_dir}/instances | jq '.[] |= del(.addDatabaseTriggered)' > ${temp_dir}/instances-new.json
      oc set data -n ${project} cm/db2aaservice-databases-watch-cm --from-file=instances=${temp_dir}/instances-new.json
    fi
  done
  log "----------"
  log "Finished checks, sleeping for 5 minutes"
  sleep 300
done
exit 0
