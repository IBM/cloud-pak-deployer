#! /bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

# --------------------------------------------------------------------------------------------------------- #
# Functions                                                                                                 #
# --------------------------------------------------------------------------------------------------------- #
command_usage() {
  echo
  echo "Usage: $0 SUBCOMMAND [ACTION] [OPTIONS]"
  echo
  echo "SUBCOMMAND:"
  echo "  environment,env           Apply configuration to create, modify or destroy an environment"
  echo "  vault                     Get, create, modify or delete secrets in the configured vault"
  echo "  build                     Build the container image for the Cloud Pak Deployer"
  echo "  help,h                    Show help"
  echo
  echo "ACTION:"
  echo "  environment:"
  echo "    apply                   Create a new or modify an existing environment"
  echo "    destroy                 Destroy an existing environment"
  echo "    logs                    Show (tail) the logs of the apply/destroy process"
  echo "    kill                    Kill the current apply/destroy process"
  echo "  vault:"
  echo "    get                     Get a secret from the vault and return its value"
  echo "    set                     Create or update a secret in the vault"
  echo "    delete                  Delete a secret from the vault"
  echo "    list                    List secrets for the specified vault group"
  echo "  build:                    No actions."
  echo
  echo "OPTIONS:"
  echo "Generic options (environment variable). You can specify the options on the command line or set an environment variable before running the $0 command:"
  echo "  --status-dir,-l <dir>         Local directory to store logs and other provisioning files (\$STATUS_DIR)"
  echo "  --config-dir,-c <dir>         Directory to read the configuration from. Must be specified. (\$CONFIG_DIR)"
  echo "  --ibm-cloud-api-key <apikey>  API key to authenticate to the IBM Cloud (\$IBM_CLOUD_API_KEY)"
  echo "  --vault-password              Password or token to login to the vault (\$VAULT_PASSWORD)"
  echo "  --vault-cert-ca-file          File with CA of login certificate (\$VAULT_CERT_CA_FILE)"
  echo "  --vault-cert-key-file         File with login certificate key (\$VAULT_CERT_KEYFILE)"
  echo "  --vault-cert-cert-file        File with login certificate (\$VAULT_CERT_CERT_FILE)"
  echo "  --extra-vars,-e <key=value>   Extra environment variable for the deployer. You can specify multiple --extra-vars"
  echo "  --cpd-develop                 Map current directory to automation scripts, only for development/debug (\$CPD_DEVELOP)"
  echo "  --cp-config-only              Skip all infrastructure provisioning and cloud pak deployment tasks and only run the Cloud Pak configuration tasks"
  echo "  -v                            Show standard ansible output (\$ANSIBLE_STANDARD_OUTPUT)"
  echo "  -vvv                          Show verbose ansible output (\$ANSIBLE_VERBOSE)"
  echo 
  echo "Options for environment subcommand:"
  echo "  --confirm-destroy             Confirm that infra may be destroyed. Required for action destroy and when apply destroys infrastructure (\$CONFIRM_DESTROY)"
  echo
  echo "Options for vault subcommand:"
  echo "  --vault-group,-vg <name>          Group of secret (\$VAULT_GROUP)"
  echo "  --vault-secret,-vs <name>         Secret name to get, set or delete (\$VAULT_SECRET)"
  echo "  --vault-secret-value,-vsv <value> Secret value to set (\$VAULT_SECRET_VALUE)"
  echo "  --vault-secret-file,-vsf <value>  File with secret value to set or get (\$VAULT_SECRET_FILE)"
  echo
  exit $1
}

# Show the logs of the currently running env process
run_env_logs() {
  if [[ "${ACTIVE_CONTAINER_ID}" != "" ]];then
    ${CONTAINER_ENGINE} logs -f ${ACTIVE_CONTAINER_ID}
  else
    ${CONTAINER_ENGINE} logs ${CURRENT_CONTAINER_ID}
  fi
}

# --------------------------------------------------------------------------------------------------------- #
# Initialize                                                                                                #
# --------------------------------------------------------------------------------------------------------- #
if [ "${CPD_DEVELOP}" == "" ];then CPD_DEVELOP=false;fi
if [ "${ANSIBLE_VERBOSE}" == "" ];then ANSIBLE_VERBOSE=false;fi
if [ "${ANSIBLE_STANDARD_OUTPUT}" == "" ];then ANSIBLE_STANDARD_OUTPUT=false;fi
if [ "${CONFIRM_DESTROY}" == "" ];then CONFIRM_DESTROY=false;fi
if [ "${CP_CONFIG_ONLY}" == "" ];then CP_CONFIG_ONLY=false;fi

arrExtraKey=()
arrExtraValue=()

# --------------------------------------------------------------------------------------------------------- #
# Check subcommand and action                                                                               #
# --------------------------------------------------------------------------------------------------------- #

# Check number of parameters
if [ "$#" -lt 1 ]; then
  command_usage
fi

# Check that subcommand is valid
export SUBCOMMAND=$(echo "$1" | tr '[:upper:]' '[:lower:]' )
case "$SUBCOMMAND" in
env|environment)
  export SUBCOMMAND="environment"
  shift 1
  ;;
vault)
  shift 1
  ;;
build)
  shift 1
  ;;
h|help)
  command_usage 0
  ;;
*) 
  echo "Invalid subcommand."
  command_usage 1
  ;;
esac

# Check that action is valid for subcommand
export ACTION=$(echo "$1" | tr '[:upper:]' '[:lower:]' )
case "$SUBCOMMAND" in
environment)
  case "$ACTION" in
  --help|-h)
    command_usage 0
    ;;
  apply|destroy|logs|kill)
    shift 1
    ;;
  *)
    echo "Invalid action for environment subcommand."
    command_usage 1
    ;;
  esac
  ;;
vault)
  case "$ACTION" in
  --help|-h)
    command_usage 0
    ;;
  get|set|delete|list)
    shift 1
    ;;
  *)
    echo "Invalid action for vault subcommand."
    command_usage 1
    ;;
  esac
  ;;
build)
  ;;
esac

# --------------------------------------------------------------------------------------------------------- #
# Parse remainder of the parameters and populate environment variables                                      #
# --------------------------------------------------------------------------------------------------------- #

# Parse parameters
PARAMS=""
while (( "$#" )); do
  case "$1" in
  --help|-h)
    command_usage 0
    ;;
  --config-dir*|-c*)
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export CONFIG_DIR="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export CONFIG_DIR=$2
      shift 2
    else
      echo "Error: Missing configuration directory for --config-dir parameter."
      command_usage 2
    fi
    fi
    ;;
  --status-dir*|-l*)
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export STATUS_DIR="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export STATUS_DIR=$2
      shift 2
    else
      echo "Error: Missing argument for --status-dir parameter."
      command_usage 2
    fi
    fi
    ;;
  --ibm-cloud-api-key*|-k*)
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export IBM_CLOUD_API_KEY="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export IBM_CLOUD_API_KEY=$2
      shift 2
    else
      echo "Error: Missing argument for --ibm-cloud-api-key parameter."
      command_usage 2
    fi
    fi
    ;;
  --extra-vars*|-e*)
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      CURRENT_EXTRA_VAR="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      CURRENT_EXTRA_VAR=$2
      shift 2
    else
      echo "Error: Missing argument for --extra-vars parameter."
      command_usage 2
    fi
    fi
    # Check if the environment variable has the format of key=value
    extra_key=$(echo ${CURRENT_EXTRA_VAR} | cut -s -d= -f1)
    extra_value=$(echo ${CURRENT_EXTRA_VAR} | cut -s -d= -f2)
    if [[ "${extra_key}" == "" || "${extra_value}" == "" ]];then
      echo "Error: --extra-vars must be specified as <key>=<value>."
      command_usage 2
    fi
    arrExtraKey+=("${extra_key}")
    arrExtraValue+=("${extra_value}")
    ;;
  --vault-secret-file*|-vsf*)
    if [[ "${SUBCOMMAND}" != "vault" ]];then
      echo "Error: --vault-secret-file is not valid for $SUBCOMMAND subcommand."
      command_usage 2
    fi
    if [ ! -z "${VAULT_SECRET_VALUE}" ];then
      echo "Error: either specify --vault-secret-file or --vault-secret-value, not both."
      command_usage 2
    fi
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export VAULT_SECRET_FILE="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export VAULT_SECRET_FILE=$2
      shift 2
    else
      echo "Error: Missing argument for --vault-secret-file parameter."
      command_usage 2
    fi
    fi
    if [ ! -z ${VAULT_SECRET_FILE} ] && [[ "${ACTION}" == "set" ]] && [ ! -f ${VAULT_SECRET_FILE} ];then
      echo "Error: Vault secret file ${VAULT_SECRET_FILE} must exist for vault set action."
      command_usage 2
    fi
    ;;
  --vault-secret-value*|-vsv*)
    if [[ "${SUBCOMMAND}" != "vault" ]];then
      echo "Error: --vault-secret-value is not valid for $SUBCOMMAND subcommand."
      command_usage 2
    fi
    if [[ "${ACTION}" != "set" ]];then
      echo "Error: --vault-secret-value is not valid for action $ACTION."
      command_usage 2
    fi
    if [ ! -z "${VAULT_SECRET_FILE}" ];then
      echo "Error: either specify --vault-secret-file or --vault-secret-value, not both."
      command_usage 2
    fi
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export VAULT_SECRET_VALUE="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export VAULT_SECRET_VALUE=$2
      shift 2
    else
      echo "Error: Missing argument for --vault-secret-value parameter."
      command_usage 2
    fi
    fi
    ;;
  # The --vault-secret must be parsed after --vault-secret-value, otherwise the secret value is already
  # picked up when the first part of the option has a match
  --vault-secret*|-vs*)
    if [[ "${SUBCOMMAND}" != "vault" ]];then
      echo "Error: --vault-secret is not valid for $SUBCOMMAND subcommand."
      command_usage 2
    fi
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export VAULT_SECRET="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export VAULT_SECRET=$2
      shift 2
    else
      echo "Error: Missing argument for --vault-secret parameter."
      command_usage 2
    fi
    fi
    ;;
  --vault-group*|-vg*)
    if [[ "${SUBCOMMAND}" != "vault" ]];then
      echo "Error: --vault-group is not valid for $SUBCOMMAND subcommand."
      command_usage 2
    fi
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export VAULT_GROUP="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export VAULT_GROUP=$2
      shift 2
    else
      echo "Error: Missing argument for --vault-group parameter."
      command_usage 2
    fi
    fi
    ;;
  --vault-password*)
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export VAULT_PASSWORD="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export VAULT_PASSWORD=$2
      shift 2
    else
      echo "Error: Missing argument for --vault-password parameter."
      command_usage 2
    fi
    fi
    ;;
  --vault-cert-ca-file*)
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export VAULT_CERT_CA_FILE="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export VAULT_CERT_CA_FILE=$2
      shift 2
    else
      echo "Error: Missing argument for --vault-cert-ca-file parameter."
      command_usage 2
    fi
    fi
    ;;
  --vault-cert-key-file*)
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export VAULT_CERT_KEY_FILE="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export VAULT_CERT_KEY_FILE=$2
      shift 2
    else
      echo "Error: Missing argument for --vault-cert-key-file parameter."
      command_usage 2
    fi
    fi
    ;;
  --vault-cert-cert-file*)
    if [[ "$1" =~ "=" ]] && [ ! -z "${1#*=}" ] && [ "${1#*=:0:1}" != "-" ];then
      export VAULT_CERT_CERT_FILE="${1#*=}"
      shift 1
    else if [ -n "$2" ] && [ ${2:0:1} != "-" ];then
      export VAULT_CERT_CERT_FILE=$2
      shift 2
    else
      echo "Error: Missing argument for --vault-cert-cert-file parameter."
      command_usage 2
    fi
    fi
    ;;
  --confirm-destroy)
    if [[ "${SUBCOMMAND}" != "environment" ]];then
      echo "Error: --confirm-destroy is not valid for $SUBCOMMAND subcommand."
      command_usage 2
    fi
    export CONFIRM_DESTROY=true
    shift 1
    ;;
  --cpd-develop)
    export CPD_DEVELOP=true
    shift 1
    ;;
  --cp-config-only)
    if [[ "${SUBCOMMAND}" != "environment" ]];then
      echo "Error: --cp-config-only is not valid for $SUBCOMMAND subcommand."
      command_usage 2
    fi
    export CP_CONFIG_ONLY=true
    shift 1
    ;;    
  -vvv)
    export ANSIBLE_VERBOSE=true
    shift 1
    ;;
  -v)
    export ANSIBLE_STANDARD_OUTPUT=true
    shift 1
    ;;

  -*|--*=)
    echo "Invalid option: $1"
    command_usage 2
    ;;
  *) # preserve remaining arguments
    PARAMS="$PARAMS $1"
    shift
    ;;
  esac
done

# --------------------------------------------------------------------------------------------------------- #
# Check container engine and build if wanted                                                                #
# --------------------------------------------------------------------------------------------------------- #

# container engine used to run the registry, either 'docker' or 'podman'
CONTAINER_ENGINE=

# Check if podman or docker command was found
if command -v podman &> /dev/null;then
  CONTAINER_ENGINE="podman"
elif command -v docker &> /dev/null;then
  CONTAINER_ENGINE="docker"
else
  echo "podman or docker command was not found."
  exit 99
fi

# If running "build" subcommand, build the image
if [ "$SUBCOMMAND" == "build" ];then
  $CONTAINER_ENGINE build -t cloud-pak-deployer ${SCRIPT_DIR}
  exit $?
fi

# --------------------------------------------------------------------------------------------------------- #
# Check invalid combinations of parameters                                                                  #
# --------------------------------------------------------------------------------------------------------- #

# Validate combination of parameters for subcommand vault
if [[ "${SUBCOMMAND}" == "vault" ]];then
  if [[ "${ACTION}" == "set" && "${VAULT_SECRET_VALUE}" == "" && "${VAULT_SECRET_FILE}" == "" ]] ;then
    echo "--vault-secret-value or --vault-secret-file must be specified for subcommand vault and action set."
    exit 1
  fi
  if [[ "${ACTION}" != "list" && "${VAULT_SECRET}" == "" ]];then
    echo "--vault-secret must be specified for subcommand vault and action ${ACTION}."
    exit 1
  fi
  if [[ "${ACTION}" == "list" && \
        ( "${VAULT_SECRET}" != "" || "${VAULT_SECRET_VALUE}" != "" || "${VAULT_SECRET_FILE}" != "" ) ]] ;then
    echo "Only --secret-group can be specified for subcommand vault and action list."
    exit 1
  fi

  if [[ "${ACTION}" != "set" && "${VAULT_SECRET_VALUE}" != "" ]];then
    echo "--vault-secret-value must not be specified for subcommand vault and action ${ACTION}."
    exit 1
  fi
  if [[ "${VAULT_SECRET_VALUE}" != "" && "${VAULT_SECRET_FILE}" != "" ]];then
    echo "Specify either --vault-secret-value or --vault-secret-file, not both."
    exit 1
  fi
fi


# --------------------------------------------------------------------------------------------------------- #
# Check existence of directories                                                                            #
# --------------------------------------------------------------------------------------------------------- #

# Validate if the configuration directory exists and has the correct subdirectories
if [ ! -d "${CONFIG_DIR}" ]; then
  echo "config directory ${CONFIG_DIR} not found."
  exit 1
fi
if [ ! -d "${CONFIG_DIR}/config" ]; then
  echo "config directory not found in directory ${CONFIG_DIR}."
  exit 1
fi
if [ ! -d "${CONFIG_DIR}/inventory" ]; then
  echo "inventory directory not found in directory ${CONFIG_DIR}."
  exit 1
fi

# --------------------------------------------------------------------------------------------------------- #
# Check existence of certificate files if specified                                                         #
# --------------------------------------------------------------------------------------------------------- #

# Ensure vault certificate files exists
if [[ ! -z $VAULT_CERT_CA_FILE && ! -f $VAULT_CERT_CA_FILE ]];then
    echo "Vault certificate CA file ${VAULT_CERT_CA_FILE} not found."
fi
if [[ ! -z $VAULT_CERT_KEY_FILE && ! -f $VAULT_CERT_KEY_FILE ]];then
    echo "Vault certificate key file ${VAULT_CERT_KEY_FILE} not found."
fi
if [[ ! -z $VAULT_CERT_CERT_FILE && ! -f $VAULT_CERT_CERT_FILE ]];then
    echo "Vault certificate file ${VAULT_CERT_CERT_FILE} not found."
fi

# Set remaining parameters
eval set -- "$PARAMS"

# --------------------------------------------------------------------------------------------------------- #
# For the remainder of the command, it is expected that the image exists                                    #
# --------------------------------------------------------------------------------------------------------- #

# Check if the cloud-pak-deployer image exists

if [[ "$(${CONTAINER_ENGINE} images -q cloud-pak-deployer:latest 2> /dev/null)" == "" ]]; then
  echo "Container image cloud-pak-deployer does not exist on the local machine, please build first."
  exit 99
fi

# --------------------------------------------------------------------------------------------------------- #
# Run the Cloud Pak Deployer                                                                                #
# --------------------------------------------------------------------------------------------------------- #

# Show warning if --cpd-develop is used
if $CPD_DEVELOP;then
  echo "Warning: CPD_DEVELOP was specified. Current directory $(pwd) will be used for automation script !!!"
  sleep 0.5
fi

# Ensure status directory exists
if [ -z $STATUS_DIR ];then
  export STATUS_DIR=$(mktemp -d)
  echo "Status directory not specified, setting to $STATUS_DIR" >&2
fi
mkdir -p $STATUS_DIR

# Ensure vault secret file exists
if [ ! -z $VAULT_SECRET_FILE ];then
  touch ${VAULT_SECRET_FILE}
fi

# Check if a container is currently running for this status directory
CURRENT_CONTAINER_ID=""
ACTIVE_CONTAINER_ID=""
if [ -f ${STATUS_DIR}/pid/container.id ];then
  CURRENT_CONTAINER_ID=$(cat ${STATUS_DIR}/pid/container.id)
  ACTIVE_CONTAINER_ID=${CURRENT_CONTAINER_ID}
  # If container ID was found, check if it is currently running
  if [ "${ACTIVE_CONTAINER_ID}" != "" ];then
    if ! ${CONTAINER_ENGINE} ps --no-trunc | grep -q ${ACTIVE_CONTAINER_ID};then
      ACTIVE_CONTAINER_ID=""
    fi
  fi
fi

# If trying to apply or destroy for an active container, just display the logs
if [[ "${ACTION}" == "apply" || "${ACTION}" == "destroy" ]];then
  if [[ "${ACTIVE_CONTAINER_ID}" != "" ]];then
    echo "Cloud Pak Deployer is already running for status directory ${STATUS_DIR}"
    echo "Showing the logs of the currently running container ${ACTIVE_CONTAINER_ID}"
    sleep 0.5
    run_env_logs
    exit 0
  fi
# Display the logs if an active or inactive container was found
elif [[ "${ACTION}" == "logs" ]];then
  if [[ "${CURRENT_CONTAINER_ID}" == "" ]];then
    echo "Error: No Cloud Pak Deployer process found for the current status directory."
    exit 1
  else
    run_env_logs
    exit 0
  fi
# Terminate if an active container was found
elif [[ "${ACTION}" == "kill" ]];then
  if [[ "${ACTIVE_CONTAINER_ID}" == "" ]];then
    echo "Error: No active Cloud Pak Deployer process found for the current status directory."
    exit 1
  else
    echo "Terminating container process ${ACTIVE_CONTAINER_ID}"
    ${CONTAINER_ENGINE} kill ${ACTIVE_CONTAINER_ID}
    exit 0
  fi
fi

# If CP_ENTITLEMENT_KEY was specified, create secret automatically
if [[ "${SUBCOMMAND}" == "environment" && "${ACTION}" == "apply" && ! -z ${CP_ENTITLEMENT_KEY} ]];then
  echo "CP_ENTITLEMENT_KEY environment variables set, creating secret first."
  ${SCRIPT_DIR}/cp-deploy.sh vault set --config-dir ${CONFIG_DIR} --status-dir ${STATUS_DIR} \
    --vault-secret ibm_cp_entitlement_key --vault-secret-value ${CP_ENTITLEMENT_KEY}
  if [ $? -ne 0 ];then
    exit 1
  fi
fi

# Build command
run_cmd="${CONTAINER_ENGINE} run"

# If running "environment" subcommand, run as daemon
if [ "$SUBCOMMAND" == "environment" ];then
  run_cmd+=" -d"
fi

if [ "$SUBCOMMAND" == "vault" ];then
  run_cmd+=" --cap-add=IPC_LOCK"
fi

run_cmd+=" -v ${STATUS_DIR}:${STATUS_DIR}:Z "

if [ ! -z $CONFIG_DIR ];then run_cmd+=" -v ${CONFIG_DIR}:${CONFIG_DIR}:Z";fi
if $CPD_DEVELOP;then run_cmd+=" -v ${PWD}:/automation_script:Z";fi

run_cmd+=" -e SUBCOMMAND=${SUBCOMMAND}"
run_cmd+=" -e ACTION=${ACTION}"
run_cmd+=" -e STATUS_DIR=${STATUS_DIR}"
run_cmd+=" -e IBM_CLOUD_API_KEY=${IBM_CLOUD_API_KEY}"
run_cmd+=" -e CONFIG_DIR=${CONFIG_DIR}"

if [ ! -z $VAULT_GROUP ];then
  run_cmd+=" -e VAULT_GROUP=${VAULT_GROUP}"
fi

if [ ! -z $VAULT_SECRET ];then
   run_cmd+=" -e VAULT_SECRET=${VAULT_SECRET} \
            -e VAULT_SECRET_VALUE=${VAULT_SECRET_VALUE} \
            -e VAULT_SECRET_FILE=${VAULT_SECRET_FILE}"
  if [ ! -z $VAULT_SECRET_FILE ];then
    run_cmd+=" -v ${VAULT_SECRET_FILE}:${VAULT_SECRET_FILE}:Z"
  fi
fi

if [ ! -z $VAULT_PASSWORD ];then
  run_cmd+=" -e VAULT_PASSWORD=${VAULT_PASSWORD}"
fi

if [ ! -z $VAULT_CERT_CA_FILE ];then
  run_cmd+=" -e VAULT_CERT_CA_FILE=${VAULT_CERT_CA_FILE}"
  run_cmd+=" -v ${VAULT_CERT_CA_FILE}:${VAULT_CERT_CA_FILE}:Z"
fi

if [ ! -z $VAULT_CERT_KEY_FILE ];then
  run_cmd+=" -e VAULT_CERT_KEY_FILE=${VAULT_CERT_KEY_FILE}"
  run_cmd+=" -v ${VAULT_CERT_KEY_FILE}:${VAULT_CERT_KEY_FILE}:Z"
fi

if [ ! -z $VAULT_CERT_CERT_FILE ];then
  run_cmd+=" -e VAULT_CERT_CERT_FILE=${VAULT_CERT_CERT_FILE}"
  run_cmd+=" -v ${VAULT_CERT_CERT_FILE}:${VAULT_CERT_CERT_FILE}:Z"
fi

run_cmd+=" -e ANSIBLE_VERBOSE=${ANSIBLE_VERBOSE}"
run_cmd+=" -e ANSIBLE_STANDARD_OUTPUT=${ANSIBLE_STANDARD_OUTPUT}"
run_cmd+=" -e CONFIRM_DESTROY=${CONFIRM_DESTROY}"
run_cmd+=" -e CP_CONFIG_ONLY=${CP_CONFIG_ONLY}"

# Handle extra variables
if [ ${#arrExtraKey[@]} -ne 0 ];then
  for (( i=0; i<${#arrExtraKey[@]}; i++ ));do
    echo "Extra parameters ($i): ${arrExtraKey[$i]}=${arrExtraValue[$i]}"
    run_cmd+=" -e ${arrExtraKey[$i]}=${arrExtraValue[$i]}"
  done
  run_cmd+=" -e EXTRA_PARMS=\"${arrExtraKey[*]}\""
fi

run_cmd+=" cloud-pak-deployer"

# If running "environment" subcommand, follow log
if [ "$SUBCOMMAND" == "environment" ];then
  CURRENT_CONTAINER_ID=$(eval $run_cmd)
  ACTIVE_CONTAINER_ID=${CURRENT_CONTAINER_ID}
  mkdir -p ${STATUS_DIR}/pid
  echo "${CURRENT_CONTAINER_ID}" > ${STATUS_DIR}/pid/container.id
  PODMAN_EXIT_CODE=$?
  run_env_logs
else
  eval $run_cmd
  PODMAN_EXIT_CODE=$?
fi

exit $PODMAN_EXIT_CODE