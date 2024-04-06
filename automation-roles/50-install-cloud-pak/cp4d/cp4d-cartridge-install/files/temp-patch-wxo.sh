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
  printf "[${LOG_TIME}] ${1}\n" | tee -a ${status_dir}/log/$project-wxo-48-patch.log
}

log "----------"
# Check if the connection to the OpenShift cluster is still valid
log "Info: Checking access to project $project"
oc get project $project
if [ $? -ne 0 ];then
  log "Error: Could not access project $project. Has the OpenShift login token expired?"
  exit 99
fi

ops_manager_patched=0
rabbit_mq_cluster_patched=0

while true;do
  log "----------"
  log "Checking OpsManager in project ${project}"
  log "----------"

  if oc get opsmanagers.mongodb.com -n ${project} mongodb-wo-mongo-ops-manager;then
    log "Info: Patching OpsManager mongodb-wo-mongo-ops-manager"
    patch_result=$(oc patch opsmanagers.mongodb.com \
            -n ${project} mongodb-wo-mongo-ops-manager \
            --type merge \
            --patch '{
                "spec": {
                    "applicationDatabase":{
                        "podSpec":{
                            "podTemplate":{
                                "metadata":{
                                    "labels":{
                                        "wo.watsonx.ibm.com/external-access":"true"
                                    }
                                }
                            }
                        }
                    }
                }
            }' 2>&1 | tee -a ${status_dir}/log/$project-wxo-48-patch.log)
    if [[ "$patch_result" != *"(no change)"* ]];then
      echo "OpsManager has been patched." | tee -a ${status_dir}/log/$project-wxo-48-patch.log
      oc delete sts -n ${project} mongodb-wo-mongo-ops-manager-db --ignore-not-found
      ops_manager_patched=1
    fi
  fi

  log "----------"
  log "Checking RabbitMQCluster in project ${project}"
  log "----------"

  if oc get rabbitmqclusters.rabbitmq.opencontent.ibm.com -n ${project} wo-rabbitmq;then
    log "Info: Patching RabbitMQCluster wo-rabbitmq"
    patch_result=$(oc patch rabbitmqclusters.rabbitmq.opencontent.ibm.com \
            -n ${project} wo-rabbitmq \
            --type merge \
            --patch '{
                "metadata":{
                    "annotations":{
                        "wo.watsonx.ibm.com/hands-off":"true"
                    }
                },
                "spec":{
                    "global":{
                        "podLabels":{
                            "wo.watsonx.ibm.com/external-access":"true"
                        }
                    }
                }
            }' 2>&1 | tee -a ${status_dir}/log/$project-wxo-48-patch.log)
    if [[ "$patch_result" != *"(no change)"* ]];then
      echo "RabbitMQCluster has been patched." | tee -a ${status_dir}/log/$project-wxo-48-patch.log
      oc delete job -n ${project} wo-rabbitmq-orchestrate-backup-label --ignore-not-found
      rabbit_mq_cluster_patched=1
    fi
  fi

  if [[ ${ops_manager_patched} -eq 1 && ${rabbit_mq_cluster_patched} -eq 1 ]];then
    log "Both OpsManager and RabbitMQCluster have been patched, exiting"
    exit 0
  fi

  log "----------"
  log "Finished checks, sleeping for 2 minutes"
  sleep 120
done
exit 0
