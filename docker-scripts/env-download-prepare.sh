#!/bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

INV_DIR="${CONFIG_DIR}/inventory"
if [ ! -d "${INV_DIR}" ]; then
  echo "inventory directory not found in directory ${CONFIG_DIR}."
  error=1
fi

echo ""
echo "Starting download preparation script..."
echo ""
cd ${SCRIPT_DIR}/..

# Set Ansible config file to use
ANSIBLE_CONFIG_FILE=$PWD/playbooks/ansible-download.cfg
if $ANSIBLE_STANDARD_OUTPUT;then ANSIBLE_CONFIG_FILE=$PWD/ansible.cfg;fi
export ANSIBLE_CONFIG=${ANSIBLE_CONFIG_FILE}

# Assemble command
run_cmd="ansible-playbook -i ${INV_DIR}"
run_cmd+=" playbooks/playbook-env-download-10-prepare.yml"
run_cmd+=" --extra-vars config_dir=${CONFIG_DIR}"
run_cmd+=" --extra-vars status_dir=${STATUS_DIR}"
run_cmd+=" ${VERBOSE_ARG}"

echo "$run_cmd" >> /tmp/deployer_run_cmd.log
eval $run_cmd