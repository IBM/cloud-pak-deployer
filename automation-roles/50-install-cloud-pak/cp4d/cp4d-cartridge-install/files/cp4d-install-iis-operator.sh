#!/bin/bash

if [ "$#" -ne 6 ]; then
    echo "Incorrect number of parameters provided."
    echo "cp4d-install-iis-operator.sh"
    echo "  <STATUS_DIR>"
    echo "  <CASE_SAVED_DIR>"
    echo "  <CASE_REPO_PATH>"
    echo "  <IIS_CASE_FILE>"
    echo "  <IBM_COMMON_SERVICE_PROJECT_NAME>"
    echo "  <INVENTORY_NAME>"
    exit 1
fi

export STATUS_DIR=$1
export CASE_SAVED_DIR=$2
export CASE_REPO_PATH=$3
export IIS_CASE=$4
export IBM_COMMON_SERVICES=$5
export INVENTORY=$6

get_logtime() {
  echo $(date "+%Y-%m-%d %H:%M:%S")
}

log() {
  LOG_TIME=$(get_logtime)
  printf "[${LOG_TIME}] ${1}\n" | tee -a ${STATUS_DIR}/log/iis_operator.log
}

log ""
log "==> 1. Save the case file ${CASE_REPO_PATH}/${IIS_CASE} to ${CASE_SAVED_DIR}"
log ""
log "=================="
cloudctl case save --case ${CASE_REPO_PATH}/${IIS_CASE} --outputdir ${CASE_SAVED_DIR}

log ""
log "==> 2. Install the inventory ${INVENTORY} operator"
log ""
log "=================="
cloudctl case launch --case ${CASE_SAVED_DIR}/${IIS_CASE} --tolerance 1 --namespace ${IBM_COMMON_SERVICES} --action installOperatorNative --inventory ${INVENTORY}

log ""
log "==> 3. Wait for the Operator pod running status"
log ""
log "=================="

max_attempts=10
counter=0 
export IIS_OPERATOR_RUNNING_STATUS=$(oc get pod -n ${IBM_COMMON_SERVICES} | grep ibm-cpd-iis-operator | grep Running | grep 1/1 | wc -l)

while [ ${IIS_OPERATOR_RUNNING_STATUS} -ne 1 ] && [ ${counter} -lt ${max_attempts} ]
do
   ((counter=counter+1))
   sleep 10
   export IIS_OPERATOR_RUNNING_STATUS=$(oc get pod -n ${IBM_COMMON_SERVICES} | grep ibm-cpd-iis-operator | grep Running | grep 1/1 | wc -l)
done

if [ ${counter} -ge ${max_attempts} ]
then
  log "IIS Operator pod did not start in the expected time window."
  exit 1
fi

log ""
log "==> 4. Completed"
log ""
log "=================="
log "IIS Operator installed and operator pod is running..."