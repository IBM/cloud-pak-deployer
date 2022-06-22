#!/bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

echo ""
echo "Starting download preparation script..."
echo ""
cd ${SCRIPT_DIR}/..

# Ensure /tmp/work exists
mkdir -p /tmp/work

# Set Ansible config file to use
ANSIBLE_CONFIG_FILE=$PWD/playbooks/ansible-download.cfg
if $ANSIBLE_STANDARD_OUTPUT || [ "$ANSIBLE_VERBOSE" != "" ];then
  ANSIBLE_CONFIG_FILE=$PWD/ansible.cfg
fi
export ANSIBLE_CONFIG=${ANSIBLE_CONFIG_FILE}

# Assemble command
run_cmd="ansible-playbook"
if [ -d "${CONFIG_DIR}/inventory" ]; then
  run_cmd+=" -i ${CONFIG_DIR}/inventory"
fi
run_cmd+=" playbooks/playbook-env-download-10-prepare.yml"
run_cmd+=" --extra-vars config_dir=${CONFIG_DIR}"
run_cmd+=" --extra-vars status_dir=${STATUS_DIR}"
run_cmd+=" --extra-vars cpd_skip_portable_registry=${CPD_SKIP_PORTABLE_REGISTRY}"
run_cmd+=" ${ANSIBLE_VERBOSE}"

echo "$run_cmd" >> /tmp/deployer_run_cmd.log
eval $run_cmd