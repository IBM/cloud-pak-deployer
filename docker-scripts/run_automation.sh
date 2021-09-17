#!/bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

error=0

# Check mandatory parameters
if [ ! -v IBM_CLOUD_API_KEY ];then
  echo "Error: environment variable IBM_CLOUD_API_KEY has not been set and is required"
  error=1
fi

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

VERBOSE_ARG=""
if $ANSIBLE_VERBOSE;then VERBOSE_ARG="-vvv";fi

# Check that subcommand is valid
export SUBCOMMAND=${SUBCOMMAND,,}
export ACTION=${ACTION,,}
case "$SUBCOMMAND" in
env|environment)
  # Set Ansible config file to use
  ANSIBLE_CONFIG_FILE=$PWD/ansible-apply.cfg
  if $ANSIBLE_STANDARD_OUTPUT;then ANSIBLE_CONFIG_FILE=$PWD/ansible.cfg;fi
  export ANSIBLE_CONFIG=${ANSIBLE_CONFIG_FILE}
  # Assemble command
  run_cmd="ansible-playbook -i ${INV_DIR}"
  if [ "$ACTION" == "apply" ];then
    if [ "$CP_CONFIG_ONLY" == "true" ];then
      run_cmd+=" playbooks/playbook-env-apply-cp-config-only.yml"
    else
      run_cmd+=" playbooks/playbook-env-apply.yml"
    fi
  elif [ "$ACTION" == "destroy" ];then
    run_cmd+=" playbooks/playbook-env-destroy.yml"
  fi
  run_cmd+=" --extra-vars config_dir=${CONFIG_DIR}"
  run_cmd+=" --extra-vars status_dir=${STATUS_DIR}"
  run_cmd+=" --extra-vars ibmcloud_api_key=${IBM_CLOUD_API_KEY}"
  run_cmd+=" --extra-vars confirm_destroy=${CONFIRM_DESTROY}"
  run_cmd+=" --extra-vars cp_config_only=${CP_CONFIG_ONLY}"
  run_cmd+=" ${VERBOSE_ARG}"
  if [ -v EXTRA_PARMS ];then
    for p in ${EXTRA_PARMS};do
      echo "Extra param $p=${!p}"
      run_cmd+=" --extra-vars $p=${!p}"
    done
  fi
  eval $run_cmd
  ;;

vault)
  ANSIBLE_CONFIG_FILE=$PWD/ansible-vault.cfg
  if $ANSIBLE_STANDARD_OUTPUT;then ANSIBLE_CONFIG_FILE=$PWD/ansible.cfg;fi
  export ANSIBLE_CONFIG=${ANSIBLE_CONFIG_FILE} && \
  ansible-playbook \
    -i ${INV_DIR} \
    playbooks/playbook-vault.yml \
    --extra-vars ACTION=${ACTION} \
    --extra-vars config_dir=${CONFIG_DIR} \
    --extra-vars status_dir=${STATUS_DIR} \
    --extra-vars ibmcloud_api_key=${IBM_CLOUD_API_KEY} \
    --extra-vars secret_group_param=${VAULT_GROUP} \
    --extra-vars secret_name=${VAULT_SECRET} \
    --extra-vars secret_payload=${VAULT_SECRET_VALUE} \
    --extra-vars secret_file=${VAULT_SECRET_FILE} ${VERBOSE_ARG}
  ;;
*) 
  echo "Invalid subcommand $SUBCOMMAND."
  command_usage 1
  ;;
esac


