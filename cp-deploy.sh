#! /bin/bash
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )

# --------------------------------------------------------------------------------------------------------- #
# Functions                                                                                                 #
# --------------------------------------------------------------------------------------------------------- #
command_usage() {
    echo "Usage: $0 SUBCOMMAND ACTION [OPTIONS]"
    exit 1
}

command_usage_invalid_subcommand() {
    echo "Invalid subcommand. Valid subcommands are:"
    echo "- environment (or env)"
    echo "- vault"
    exit 1
}

command_action_invalid_env() {
    echo "Invalid action for environment subcommand. Valid actions are:"
    echo "- apply"
    echo "- destroy"
    exit 1
}

command_action_invalid_vault() {
    echo "Invalid action for vault subcommand. Valid actions are:"
    echo "- get"
    echo "- set"
    echo "- delete"
    exit 1
}

# --------------------------------------------------------------------------------------------------------- #
# Check subcommand and action                                                                               #
# --------------------------------------------------------------------------------------------------------- #

# Check number of parameters
if [ "$#" -lt 2 ]; then
    command_usage
fi

# Check that subcommand is valid
export SUBCOMMAND=${1,,}
case "$SUBCOMMAND" in
env|environment)
    export SUBCOMMAND="environment"
    shift 1
    ;;
vault)
    shift 1
    ;;
*) 
    command_usage_invalid_subcommand
    ;;
esac

# Check that action is valid for subcommand
export ACTION=${1,,}
case "$SUBCOMMAND" in
environment)
    case "$ACTION" in
    apply|destroy)
        shift 1
        ;;
    *)
        command_action_invalid_env
        ;;
    esac
    ;;
vault)
    case "$ACTION" in
    get|set|delete)
        shift 1
        ;;
    *)
        command_action_invalid_vault
        ;;
    esac
    ;;
esac

# --------------------------------------------------------------------------------------------------------- #
# Parse remainder of the parameters and populate environment variables                                      #
# --------------------------------------------------------------------------------------------------------- #

# Parse parameters
PARAMS=""
while (( "$#" )); do
  case "$1" in
    --config-dir|-c)
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        export CONFIG_DIR=$2
        shift 2
      else
        echo "Error: Missing configuration directory for --config-dir parameter"
        exit 2
      fi
      ;;
    --config-repo-url|-r)
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        export CONFIG_REPO_URL=$2
        shift 2
      else
        echo "Error: Missing configuration repository for --config-repo-url parameter"
        exit 2
      fi
      ;;
    --context-dir|-rd)
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        export CONTEXT_DIR=$2
        shift 2
      else
        echo "Error: Missing context directory for --context-dir parameter"
        exit 2
      fi
      ;;
    --config-access-token|-t)
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        export GIT_ACCESS_TOKEN=$2
        shift 2
      else
        echo "Error: Missing argument for --git-access-token parameter"
        exit 2
      fi
      ;;
    --ibm-cloud-api-key|-k)
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        export IBM_CLOUD_API_KEY=$2
        shift 2
      else
        echo "Error: Missing argument for --ibm-cloud-api-key parameter"
        exit 2
      fi
      ;;
    --vault-secret|-s)
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        export VAULT_SECRET=$2
        shift 2
      else
        echo "Error: Missing argument for --vault-secret parameter"
        exit 2
      fi
      ;;
    --vault-secret-value|-sv)
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        export VAULT_SECRET_VALUE=$2
        shift 2
      else
        echo "Error: Missing argument for --vault-secret-value parameter"
        exit 2
      fi
      ;;
    --log-dir|-l)
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        export LOG_DIR=$2
        shift 2
      else
        echo "Error: Missing argument for --log-dir parameter"
        exit 2
      fi
      ;;
    *) # preserve remaining arguments
      PARAMS="$PARAMS $1"
      shift
      ;;
  esac
done

# Set remaining parameters
eval set -- "$PARAMS"

# --------------------------------------------------------------------------------------------------------- #
# The remainder of the parameters will be checked in the pod                                                #
# --------------------------------------------------------------------------------------------------------- #

# Check if podman command was found
if ! command -v podman &> /dev/null;then
    echo "podman command was not found."
    exit 99
fi

# Check if the cloud-pak-deployer image exists
if ! podman image exists cloud-pak-deployer;then
    echo "Container image cloud-pak-deployer does not exist on the local machine, please build first."
    exit 99
fi

# --------------------------------------------------------------------------------------------------------- #
# Run the Cloud Pak Deployer                                                                                #
# --------------------------------------------------------------------------------------------------------- #

# Ensure log directory exists
if [ -z $LOG_DIR ];then
    export LOG_DIR=$(mktemp -d)
    echo "Log directory not specified, setting to $LOG_DIR" >&2
fi
mkdir -p $LOG_DIR

podman run \
  -v ${LOG_DIR}:/Data:Z \
  -v ${CONFIG_DIR}:${CONFIG_DIR}:Z \
  -e CONFIG_DIR=${CONFIG_DIR} \
  -e IBM_CLOUD_API_KEY=${IBM_CLOUD_API_KEY} \
  cloud-pak-deployer

PODMAN_EXIT_CODE=$?
exit $PODMAN_EXIT_CODE

