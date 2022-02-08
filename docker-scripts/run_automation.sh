#!/bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

error=0

# Check mandatory parameters
if [ ! -v CONFIG_DIR ];then
  echo "Error: environment CONFIG_DIR must be specified"
  error=1
fi

# Validate if the configuration directory exists
CONF_DIR="${CONFIG_DIR}/config"
if [ ! -d "${CONF_DIR}" ]; then
  echo "config directory not found in directory ${CONFIG_DIR}."
  error=1
fi

  # Validate if the inventory directory exists
INV_DIR="${CONFIG_DIR}/inventory"
if [ ! -d "${INV_DIR}" ]; then
  echo "inventory directory not found in directory ${CONFIG_DIR}."
  error=1
fi

if [[ error -ne 0 ]];then
  echo "Error running deployer"
  exit 1
fi

echo ""
echo "Starting Automation script..."
echo ""
cd ${SCRIPT_DIR}/..

# Check that subcommand is valid
export SUBCOMMAND=${SUBCOMMAND,,}
export ACTION=${ACTION,,}
case "$SUBCOMMAND" in
env|environment)
  # Set Ansible config file to use
  ANSIBLE_CONFIG_FILE=$PWD/ansible-apply.cfg
  if $ANSIBLE_STANDARD_OUTPUT || [ "$ANSIBLE_VERBOSE" != "" ];then
    ANSIBLE_CONFIG_FILE=$PWD/ansible.cfg
  fi
  export ANSIBLE_CONFIG=${ANSIBLE_CONFIG_FILE}
  # Assemble command
  run_cmd="ansible-playbook -i ${INV_DIR}"
  if [ "$ACTION" == "apply" ];then
    if [ "$CHECK_ONLY" == "true" ];then
      run_cmd+=" playbooks/playbook-env-apply-check-only.yml"
    elif [ "$CP_CONFIG_ONLY" == "true" ];then
      run_cmd+=" playbooks/playbook-env-apply-cp-config-only.yml"
    else
      run_cmd+=" playbooks/playbook-env-apply.yml"
    fi
  elif [ "$ACTION" == "destroy" ];then
    run_cmd+=" playbooks/playbook-env-destroy.yml"
  elif [ "$ACTION" == "download" ];then
    run_cmd+=" playbooks/playbook-env-download-20-execute.yml"
  fi
  run_cmd+=" --extra-vars cpd_action=${ACTION}"
  run_cmd+=" --extra-vars config_dir=${CONFIG_DIR}"
  run_cmd+=" --extra-vars status_dir=${STATUS_DIR}"
  run_cmd+=" --extra-vars ibmcloud_api_key=${IBM_CLOUD_API_KEY}"
  run_cmd+=" --extra-vars cp_entitlement_key=${CP_ENTITLEMENT_KEY}"
  run_cmd+=" --extra-vars confirm_destroy=${CONFIRM_DESTROY}"
  run_cmd+=" --extra-vars cpd_skip_infra=${CPD_SKIP_INFRA}"
  run_cmd+=" --extra-vars cp_config_only=${CP_CONFIG_ONLY}"
  run_cmd+=" --extra-vars cpd_airgap=${CPD_AIRGAP}"

  if [ ! -z $VAULT_PASSWORD ];then
    run_cmd+=" --extra-vars VAULT_PASSWORD=${VAULT_PASSWORD}"
  fi
  if [ ! -z $VAULT_CERT_CA_FILE ];then
    run_cmd+=" --extra-vars VAULT_CERT_CA_FILE=${VAULT_CERT_CA_FILE}"
  fi
  if [ ! -z $VAULT_CERT_KEY_FILE ];then
    run_cmd+=" --extra-vars VAULT_CERT_KEY_FILE=${VAULT_CERT_KEY_FILE}"
  fi
  if [ ! -z $VAULT_CERT_CERT_FILE ];then
    run_cmd+=" --extra-vars VAULT_CERT_CERT_FILE=${VAULT_CERT_CERT_FILE}"
  fi
  run_cmd+=" ${ANSIBLE_VERBOSE}"
  if [ -v EXTRA_PARMS ];then
    for p in ${EXTRA_PARMS};do
      echo "Extra param $p=${!p}"
      run_cmd+=" --extra-vars $p=${!p}"
    done
  fi
  # Make sure that the logs of the Ansible playbook are written to a log file
  mkdir -p ${STATUS_DIR}/log
  run_cmd+=" | tee ${STATUS_DIR}/log/cloud-pak-deployer.log"
  echo "$run_cmd" >> /tmp/deployer_run_cmd.log
  echo "RUN COMMAND: $run_cmd"
  eval $run_cmd
  ;;

vault)
  ANSIBLE_CONFIG_FILE=$PWD/ansible-vault.cfg
  if $ANSIBLE_STANDARD_OUTPUT || [ "$ANSIBLE_VERBOSE" != "" ];then
    ANSIBLE_CONFIG_FILE=$PWD/ansible.cfg
  fi

  export ANSIBLE_CONFIG=${ANSIBLE_CONFIG_FILE}
  run_cmd="ansible-playbook -i ${INV_DIR}"
  run_cmd+=" playbooks/playbook-vault.yml"
  run_cmd+=" --extra-vars ACTION=${ACTION}"
  run_cmd+=" --extra-vars config_dir=${CONFIG_DIR}"
  run_cmd+=" --extra-vars status_dir=${STATUS_DIR}"
  run_cmd+=" --extra-vars ibmcloud_api_key=${IBM_CLOUD_API_KEY}"
  run_cmd+=" --extra-vars secret_group_param=${VAULT_GROUP}"
  run_cmd+=" --extra-vars secret_name=${VAULT_SECRET}"
  run_cmd+=" --extra-vars secret_payload=${VAULT_SECRET_VALUE}"
  run_cmd+=" --extra-vars secret_file=${VAULT_SECRET_FILE}"
  if [ ! -z $VAULT_PASSWORD ];then
    run_cmd+=" --extra-vars VAULT_PASSWORD=${VAULT_PASSWORD}"
  fi
  if [ ! -z $VAULT_CERT_CA_FILE ];then
    run_cmd+=" --extra-vars VAULT_CERT_CA_FILE=${VAULT_CERT_CA_FILE}"
  fi
  if [ ! -z $VAULT_CERT_KEY_FILE ];then
    run_cmd+=" --extra-vars VAULT_CERT_KEY_FILE=${VAULT_CERT_KEY_FILE}"
  fi
  if [ ! -z $VAULT_CERT_CERT_FILE ];then
    run_cmd+=" --extra-vars VAULT_CERT_CERT_FILE=${VAULT_CERT_CERT_FILE}"
  fi
  run_cmd+=" ${ANSIBLE_VERBOSE}"
  if [ -v EXTRA_PARMS ];then
    for p in ${EXTRA_PARMS};do
      echo "Extra param $p=${!p}"
      run_cmd+=" --extra-vars $p=${!p}"
    done
  fi
  echo "$run_cmd" >> /tmp/deployer_run_cmd.log
  eval $run_cmd
  ;;
*) 
  echo "Invalid subcommand $SUBCOMMAND."
  command_usage 1
  ;;
esac


