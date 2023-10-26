#!/bin/bash

# Compute IPC kernel parameters as per IBM Documentation topic
# https://www.ibm.com/support/knowledgecenter/SSEPGG_11.1.0/com.ibm.db2.luw.qb.server.doc/doc/c0057140.html
# and generate the Node Tuning Operator CR yaml.

tuned_cr_yaml="/tmp/Db2UnodeTuningCR.yaml"
mem_limit_Gi=0
node_label=""
cr_name="cp4d-ipc"
cr_profile_name="cp4d-ipc"
cr_namespace="openshift-cluster-node-tuning-operator"
create_cr="false"
delete_cr="false"

usage() {
    cat <<-USAGE #| fmt
    Usage: $0 [OPTIONS] [arg]

    OPTIONS:
    =======
    * -m|--mem-limit mem_limit  : The memory.limit (Gi) to be applied to Db2U deployment.
    * [-l|--label node_label]   : The node label to use for dedicated Cp4D deployments.
    * [-f|--file yaml_output]   : The NodeTuningOperator CR YAML output file. Default /tmp/Db2UnodeTuningCR.yaml.
    * [-c|--create]             : Create the NodeTuningOperator CR ${cr_name} using the generated CR yaml file.
    * [-d|--delete]             : Delete the NodeTuningOperator CR ${cr_name}.
    * [-h|--help]               : Display the help text of the script.
USAGE
}

[[ $# -lt 1 ]] && { usage && exit 1; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--file) shift; tuned_cr_yaml=$1
        ;;
        -m|--mem-limit) shift; mem_limit_Gi=$1
        ;;
        -l|--label) shift; node_label=$1
        ;;
        -c|--create) create_cr="true"
        ;;
        -d|--delete) delete_cr="true"
        ;;
        -h|--help) usage && exit 0
        ;;
        *) usage && exit 1
        ;;
	esac
	shift
done

((ram_in_BYTES=mem_limit_Gi * 1073741824))
((ram_GB=ram_in_BYTES / (1024 * 1024 * 1024)))
((IPCMNI_LIMIT=32 * 1024))
tr ' ' '\n' < /proc/cmdline | grep -q ipcmni_extend && ((IPCMNI_LIMIT=8 * 1024 * 1024))

#
### =============== functions ================ ###
#
# Compute the required kernel IPC parameter values
compute_kernel_ipc_params() {
    local PAGESZ=$(getconf PAGESIZE)

    # Global vars
    ((shmmni=256 * ram_GB))
    shmmax=${ram_in_BYTES}
    ((shmall=2 * (ram_in_BYTES / PAGESZ)))
    ((msgmni=1024 * ram_GB))
    msgmax=65536
    msgmnb=${msgmax}
    SEMMSL=250
    SEMMNS=256000
    SEMOPM=32
    SEMMNI=${shmmni}

    # RH bugzilla https://access.redhat.com/solutions/4968021. Limit SEMMNI, shmmni and msgmni to the max
    # supported by the Linux kernel -- 32k (default) or 8M if kernel boot parameter 'ipcmni_extend' is set.
    ((SEMMNI=SEMMNI < IPCMNI_LIMIT ? SEMMNI : IPCMNI_LIMIT))
    ((shmmni=shmmni < IPCMNI_LIMIT ? shmmni : IPCMNI_LIMIT))
    ((msgmni=msgmni < IPCMNI_LIMIT ? msgmni : IPCMNI_LIMIT))
}

# Generate NodeTuning Operator YAML file
gen_tuned_cr_yaml() {
    # Generate YAML file for NodeTuning CR and save as ${tuned_cr_yaml}
    cat <<-EOF > ${tuned_cr_yaml}
apiVersion: tuned.openshift.io/v1
kind: Tuned
metadata:
  name: ${cr_name}
  namespace: ${cr_namespace}
spec:
  profile:
  - name: ${cr_profile_name}
    data: |
      [main]
      summary=Tune IPC Kernel parameters on OpenShift nodes running Db2U engine PODs
      include=openshift-node

      [sysctl]
      kernel.shmmni = ${shmmni}
      kernel.shmmax = ${shmmax}
      kernel.shmall = ${shmall}
      kernel.sem = ${SEMMSL} ${SEMMNS} ${SEMOPM} ${SEMMNI}
      kernel.msgmni = ${msgmni}
      kernel.msgmax = ${msgmax}
      kernel.msgmnb = ${msgmnb}

  recommend:
  - match:
    - label: node-role.kubernetes.io/worker
EOF

    # Add the optional dedicated label into match array
    if [[ -n "${node_label}" ]]; then
        cat <<-EOF >> ${tuned_cr_yaml}
    - label: icp4data
      value: ${node_label}
EOF
    fi

    # Add the priority and profile keys
    cat <<-EOF >> ${tuned_cr_yaml}
    priority: 10
    profile: ${cr_profile_name}
EOF

    [[ "${create_cr}" == "true" ]] && return
    cat <<-MSG
===============================================================================
* Successfully generated the Node Tuning Operator Custom Resource Definition as
  ${tuned_cr_yaml} YAML with Db2U specific IPC sysctl settings.

* Please run 'oc create -f ${tuned_cr_yaml}' on the master node to
  create the Node Tuning Operator CR to apply those customized sysctl values.
===============================================================================
MSG
}

create_tuned_cr() {
    echo "Creating the Node Tuning Operator Custom Resource for Db2U IPC kernel parameter tuning ..."
    oc create -f ${tuned_cr_yaml}
    sleep 2

    # List the NodeTuning CR and describe
    oc -n ${cr_namespace} get Tuned/${cr_name}
    echo ""

    echo "The CR of the Node Tuning Operator deployed"
    echo "--------------------------------------------"
    oc -n ${cr_namespace} describe Tuned/${cr_name}
    echo ""
}

delete_tuned_cr() {
    echo "Deleting the Node Tuning Operator Custom Resource used for Db2U IPC kernel parameter tuning ..."
    oc -n ${cr_namespace} get Tuned/${cr_name} --no-headers -ojsonpath='{.kind}' | grep -iq tuned || \
        { echo "No matching CR found ..." && exit 0; }
    oc -n ${cr_namespace} delete Tuned/${cr_name}
    echo ""
    sleep 2

    # Get the list of containerized tuned PODs (DaemonSet) deployed on the cluster
    local tuned_pods=( $(oc -n ${cr_namespace} get po --selector openshift-app=tuned --no-headers -ojsonpath='{.items[*].metadata.name}') )
    # Remove the tuned profile directory deployed on those PODs
    for p in "${tuned_pods[@]}"; do
        echo "Removing the installed tuned profile ${cr_profile_name} on POD: $p"
        oc -n ${cr_namespace} exec -it $p -- bash -c "rm -fr /etc/tuned/${cr_profile_name}"
    done
    echo ""
}

#
### ================== Main ==================== ###
#

[[ "${delete_cr}" == "true" ]] && { delete_tuned_cr && exit 0; }

compute_kernel_ipc_params

gen_tuned_cr_yaml

[[ "${create_cr}" == "true" ]] && create_tuned_cr

exit 0